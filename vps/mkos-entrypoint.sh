#!/bin/zsh
# MK-OS gateway self-heal + config-assertion wrapper (VERSION-CONTROLLED in the repo,
# deployed to /opt/data/mkos-entrypoint.sh — on the volume, so it survives BOTH
# `docker restart` and `docker compose up -d` recreate). Set as the container entrypoint
# via docker-compose.yml. It applies durability + determinism fixes, then hands off to the
# image's own /entrypoint.sh (which launches `hermes gateway run` in webhook mode):
#
#   1) Verify Mem0 pgvector + Gemini deps (psycopg, google-genai) are present. As of the
#      vps/Dockerfile build, these are baked into the image at build time, so this is a
#      fast no-op in normal operation — kept as belt-and-suspenders in case a future image
#      swap or manual `docker exec` ever wipes them, so the gateway self-heals instead of
#      silently running without Mem0 rather than hard-failing.
#   2) ASSERT our model config every boot — deterministically overriding any image drift
#      (e.g. the stock image's nexos.ai injection). OUR model is the version-controlled choice.
#   3) Start Syncthing in the background (hermes-inbox folder, already paired with the
#      iMac since 2026-07-12 — see git history). This is what lets an agent turn (VPS or
#      any profile) drop a file under /opt/data/Inbox/Hermes and have it show up in
#      Master 2.0/00-Inbox on the Mac/iMac for triage (e.g. a drafted contact note).
#      Config/certs live on the data volume (/opt/data/.local/share/syncthing), so pairing
#      survives recreate; only the *process* needs restarting on every boot, hence launching
#      it here rather than relying on it to already be running.
#   4) Wait out any prior Telegram getUpdates session so the first poll (if ever polling) is
#      conflict-free. NOTE: this deployment runs WEBHOOK mode (no polling), so this is a
#      belt-and-suspenders no-op kept only to match the proven boot sequence.
#      This wrapper never itself calls getUpdates.
set -u
LOG=/opt/data/logs/gateway.log
mkdir -p /opt/data/logs
log() { echo "[mkos-preflight $(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG" 2>&1; }

VENV=/opt/hermes/.venv
export UV_CACHE_DIR=/tmp/uvcache
# The venv is root-owned ("sealed") and has no pip; uv installs into it as root.
# Normally a no-op — vps/Dockerfile bakes these in at build time. This check only
# does real work if something wiped them after the image was built.
log "checking venv deps (psycopg[binary,pool], google-genai) — should be baked into the image"
if "$VENV/bin/python" -c "import psycopg, google.genai" 2>/dev/null; then
  log "venv deps present (image build baked them in, as expected)"
else
  log "deps missing (unexpected — image build should have baked them in) — self-healing via uv as root"
  uv pip install --python "$VENV/bin/python" "psycopg[binary,pool]" google-genai \
    >> /opt/data/logs/mkos-preflight.log 2>&1 && log "deps installed" || log "dep install FAILED (non-fatal, continuing)"
fi

# 2) Assert OUR model config (version-controlled) — neutralizes any image-baked override.
if [[ -f /opt/data/config.yaml ]]; then
  log "asserting MK-OS model config (openai-codex / gpt-5.6-sol)"
  gosu hermes hermes config set model.provider openai-codex   >> /opt/data/logs/mkos-preflight.log 2>&1 || true
  gosu hermes hermes config set model.default  gpt-5.6-sol     >> /opt/data/logs/mkos-preflight.log 2>&1 || true
  gosu hermes hermes config set model.base_url https://chatgpt.com/backend-api/codex >> /opt/data/logs/mkos-preflight.log 2>&1 || true
fi

# 3) Launch Syncthing (backgrounded — must not block the gateway boot below).
#    --home points at the already-paired config on the data volume; --no-browser/--no-restart
#    match the headless-server invocation used on the iMac side.
ST_BIN=/opt/data/.local/bin/syncthing
ST_HOME=/opt/data/.local/share/syncthing
if [[ -x "$ST_BIN" && -f "$ST_HOME/config.xml" ]]; then
  log "starting Syncthing (hermes-inbox) in background"
  gosu hermes sh -c "'$ST_BIN' serve --home='$ST_HOME' --no-browser --no-restart >> /opt/data/logs/syncthing.log 2>&1 &"
else
  log "Syncthing binary/config not found at $ST_BIN / $ST_HOME/config.xml — skipping (non-fatal)"
fi

log "waiting 60s for any prior Telegram getUpdates session to expire (webhook mode: no-op safety)"
sleep 60

log "handoff to image entrypoint (/entrypoint.sh -> hermes gateway run, webhook mode)"
exec /entrypoint.sh "$@"

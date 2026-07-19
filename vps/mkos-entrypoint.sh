#!/bin/zsh
# MK-OS gateway self-heal + config-assertion wrapper (VERSION-CONTROLLED in the repo,
# deployed to /opt/data/mkos-entrypoint.sh — on the volume, so it survives BOTH
# `docker restart` and `docker compose up -d` recreate). Set as the container entrypoint
# via docker-compose.yml. It applies durability + determinism fixes, then hands off to the
# image's own /entrypoint.sh (which launches `hermes gateway run` in webhook mode):
#
#   1) Reinstall Mem0 pgvector + Gemini deps if a recreate wiped the sealed venv.
#   2) ASSERT our model config every boot — deterministically overriding any image drift
#      (e.g. the stock image's nexos.ai injection). OUR model is the version-controlled choice.
#   3) Wait out any prior Telegram getUpdates session so the first poll (if ever polling) is
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
log "ensuring venv deps (psycopg[binary,pool], google-genai)"
if "$VENV/bin/python" -c "import psycopg, google.genai" 2>/dev/null; then
  log "venv deps already present"
else
  log "deps missing (fresh image/recreate) — installing via uv as root"
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

log "waiting 60s for any prior Telegram getUpdates session to expire (webhook mode: no-op safety)"
sleep 60

log "handoff to image entrypoint (/entrypoint.sh -> hermes gateway run, webhook mode)"
exec /entrypoint.sh "$@"

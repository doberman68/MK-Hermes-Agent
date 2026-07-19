#!/usr/bin/env bash
# MK-OS Telegram gateway watchdog — runs on the VPS HOST (independent of the Hermes
# container). Verifies the gateway is serving Telegram BY BEHAVIOR and AUTO-RECOVERS a wedge.
#
# Checks: container up + cron-ticker heartbeat freshness (personal profile) + getMe +
#   getWebhookInfo (url/last_error/pending) + a REAL webhook-DELIVERY probe: POST a benign
#   synthetic Telegram update straight to the gateway's :8443 server (via the container bridge
#   IP, bypassing Traefik's Telegram-only IP allowlist) with the correct secret_token, and
#   require HTTP 200. This proves the delivery path actually works — no more false-HEALTHY.
# Recovery: on a genuine WEDGE (probe fails / heartbeat stale / container down) it `docker
#   restart`s the container (rate-limited by RECOVER_COOLDOWN); the 1-min webhook-keeper
#   handles mere registration drops. Alerts (and recovery notices) go via direct Telegram.
# Exit 0 = healthy, 1 = unhealthy. Usage: telegram-watchdog.sh [--dry-run]
set -uo pipefail

DATA=/docker/hermes-agent-bfcq/data
CONTAINER=hermes-agent-bfcq-hermes-agent-1
HEARTBEAT="$DATA/profiles/personal/cron/ticker_heartbeat"
ENV_FILE="$DATA/.env"
CHAT_ID=8875232358
STALE_THRESHOLD=600
REALERT_EVERY=1800
RECOVER_COOLDOWN=900          # min seconds between auto-restarts
WD_DIR=/opt/mkos-watchdog
STATE_FILE="$WD_DIR/state"
RESTART_STATE="$WD_DIR/last_restart"
LOG="$WD_DIR/watchdog.log"

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
mkdir -p "$WD_DIR"
NOW=$(date +%s)
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

TOKEN=$(grep -hoE '^TELEGRAM_BOT_TOKEN=[^ ]+' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\''\r')
problems=(); wedge=0

# 1) container running
running=$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo "false")
if [ "$running" != "true" ]; then problems+=("container not running (State.Running=$running)"); wedge=1; fi

# 2) cron-ticker heartbeat freshness (personal profile — gateway liveness)
hb_mtime=$(stat -c %Y "$HEARTBEAT" 2>/dev/null || echo 0)
hb_age=$(( NOW - hb_mtime ))
[ "$hb_mtime" -gt 0 ] || { problems+=("ticker heartbeat missing"); wedge=1; }
if [ "$hb_mtime" -gt 0 ] && [ "$hb_age" -gt "$STALE_THRESHOLD" ]; then
  problems+=("ticker heartbeat STALE: ${hb_age}s (> ${STALE_THRESHOLD}s)"); wedge=1
fi

# 3) getMe (Telegram reachable + token valid)
gm_user=""
if [ -n "$TOKEN" ]; then
  gm_user=$(curl -4 -s -m 10 "https://api.telegram.org/bot$TOKEN/getMe" | grep -oE '"username":"[^"]*"' | cut -d'"' -f4)
  [ -n "$gm_user" ] || problems+=("getMe FAILED (Telegram unreachable/token invalid)")
else
  problems+=("no TELEGRAM_BOT_TOKEN in $ENV_FILE")
fi

# 4) getWebhookInfo (registration + delivery errors) — registration itself is kept by webhook-keeper
if [ -n "$TOKEN" ]; then
  whi=$(curl -4 -s -m 10 "https://api.telegram.org/bot$TOKEN/getWebhookInfo" 2>/dev/null)
  wurl=$(printf '%s' "$whi" | python3 -c "import sys,json;print(json.load(sys.stdin)['result'].get('url') or '')" 2>/dev/null)
  werr=$(printf '%s' "$whi" | python3 -c "import sys,json;print(json.load(sys.stdin)['result'].get('last_error_message') or '')" 2>/dev/null)
  wpend=$(printf '%s' "$whi" | python3 -c "import sys,json;print(json.load(sys.stdin)['result'].get('pending_update_count',0))" 2>/dev/null)
  [ -n "$wurl" ] || problems+=("webhook URL NOT registered")
  [ -z "$werr" ] || problems+=("webhook last_error: $werr")
  if printf '%s' "${wpend:-0}" | grep -qE '^[0-9]+$'; then
    [ "$wpend" -le 20 ] || problems+=("webhook pending=$wpend not draining")
  fi
fi

# 5) REAL behavioral probe — synthetic update straight to the gateway's :8443 (bypasses Traefik).
ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER" 2>/dev/null)
hookpath=$(docker exec "$CONTAINER" printenv TELEGRAM_WEBHOOK_URL 2>/dev/null | sed -E 's#^https?://[^/]+##')
wsec=$(docker exec "$CONTAINER" printenv TELEGRAM_WEBHOOK_SECRET 2>/dev/null)
if [ -n "$ip" ] && [ -n "$hookpath" ] && [ -n "$wsec" ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 8 -X POST "http://$ip:8443$hookpath" \
    -H "X-Telegram-Bot-Api-Secret-Token: $wsec" -H "Content-Type: application/json" \
    -d "{\"update_id\":$NOW}" 2>/dev/null)
  if [ "$code" != "200" ]; then problems+=("webhook delivery probe FAILED (http=$code)"); wedge=1; fi
else
  problems+=("webhook probe could not run (ip/path/secret unresolved)")
fi

# ---- verdict ----
if [ "${#problems[@]}" -eq 0 ]; then
  verdict="HEALTHY"; detail="container up; heartbeat ${hb_age}s; bot @${gm_user}; webhook registered + delivery-probe 200"
else
  verdict="UNHEALTHY"; detail=$(printf '%s; ' "${problems[@]}")
fi
line="$(ts) $verdict — $detail"
echo "$line"; echo "$line" >> "$LOG" 2>/dev/null

# ---- auto-recovery on a genuine wedge (rate-limited) ----
recovery_note=""
if [ "$verdict" = "UNHEALTHY" ] && [ "$wedge" = 1 ]; then
  last_restart=$(cat "$RESTART_STATE" 2>/dev/null || echo 0)
  if [ $(( NOW - last_restart )) -ge "$RECOVER_COOLDOWN" ]; then
    if [ "$DRY" = 1 ]; then
      recovery_note="[dry-run] would docker restart $CONTAINER"
    else
      docker restart "$CONTAINER" >/dev/null 2>&1 && recovery_note="auto-recovery: docker restart issued" || recovery_note="auto-recovery: docker restart FAILED"
      echo "$NOW" > "$RESTART_STATE"
    fi
    echo "$(ts) $recovery_note" | tee -a "$LOG"
  else
    recovery_note="auto-recovery on cooldown ($(( RECOVER_COOLDOWN - (NOW - last_restart) ))s left)"
  fi
fi

# ---- alerting (dedup + rate-limit) via direct Telegram (gateway-independent) ----
prev_status=$(cut -d' ' -f1 "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")
prev_alert_ts=$(cut -d' ' -f2 "$STATE_FILE" 2>/dev/null || echo 0)
send() {
  [ "$DRY" = 1 ] && { echo "[dry-run] would send: $1"; return 0; }
  [ -n "$TOKEN" ] || return 1
  curl -4 -s -m 10 -o /dev/null --data-urlencode "chat_id=$CHAT_ID" --data-urlencode "text=$1" "https://api.telegram.org/bot$TOKEN/sendMessage"
}
if [ "$verdict" = "UNHEALTHY" ]; then
  if [ "$prev_status" != "UNHEALTHY" ] || [ $(( NOW - prev_alert_ts )) -ge "$REALERT_EVERY" ]; then
    send "🚨 MK-OS watchdog: VPS Hermes gateway UNHEALTHY
$detail${recovery_note:+
$recovery_note}
(host $(hostname), $(ts))" >/dev/null
    echo "UNHEALTHY $NOW" > "$STATE_FILE"
  else
    echo "UNHEALTHY $prev_alert_ts" > "$STATE_FILE"
  fi
  exit 1
else
  if [ "$prev_status" = "UNHEALTHY" ]; then
    send "✅ MK-OS watchdog: VPS Hermes gateway RECOVERED
$detail
($(ts))" >/dev/null
  fi
  echo "HEALTHY $NOW" > "$STATE_FILE"
  exit 0
fi

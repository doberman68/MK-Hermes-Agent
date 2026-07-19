#!/usr/bin/env bash
# MK-OS webhook keeper — runs on the VPS HOST every minute (see mkos-watchdog.cron).
# Makes webhook registration DETERMINISTIC: if a gateway restart/reconnect window drops
# the Telegram webhook, re-assert it within <=60s. Idempotent — only calls setWebhook when
# the current registration != our expected URL (so it does nothing on the happy path).
# The gateway runs webhook mode (never polls / never deleteWebhook), so this never flap-wars.
set -uo pipefail

DATA=/docker/hermes-agent-bfcq/data
CID=hermes-agent-bfcq-hermes-agent-1
LOG=/opt/mkos-watchdog/webhook-keeper.log
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
mkdir -p /opt/mkos-watchdog

TOKEN=$(grep -hoE '^TELEGRAM_BOT_TOKEN=[^ ]+' "$DATA/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'\''\r')
URL=$(docker exec "$CID" printenv TELEGRAM_WEBHOOK_URL 2>/dev/null)
SEC=$(docker exec "$CID" printenv TELEGRAM_WEBHOOK_SECRET 2>/dev/null)
[ -n "$TOKEN" ] && [ -n "$URL" ] && [ -n "$SEC" ] || { echo "$(ts) SKIP (missing token/url/secret)" >> "$LOG"; exit 0; }

cur=$(curl -4 -s -m 8 "https://api.telegram.org/bot$TOKEN/getWebhookInfo" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['result'].get('url') or '')" 2>/dev/null)

if [ "$cur" = "$URL" ]; then
  exit 0   # happy path: already registered correctly, do nothing
fi

resp=$(curl -4 -s -m 10 "https://api.telegram.org/bot$TOKEN/setWebhook" \
  --data-urlencode "url=$URL" \
  --data-urlencode "secret_token=$SEC" \
  -d "drop_pending_updates=false" \
  -d 'allowed_updates=["message","edited_message","callback_query","my_chat_member"]')
ok=$(printf '%s' "$resp" | python3 -c "import sys,json;print(json.load(sys.stdin).get('ok'))" 2>/dev/null)
echo "$(ts) re-registered webhook (was:'${cur:-empty}') ok=$ok" >> "$LOG"

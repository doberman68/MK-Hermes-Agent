# VPS Hermes deployment (version-controlled)

The Hostinger VPS is the **sole Telegram gateway** (webhook mode) and hosts **central Mem0**
(Constitution §3/§5). This directory is the source of truth for that deployment so Hostinger's
`:latest` image can never silently mutate it again.

## Files
- `docker-compose.yml` — the gateway service. **Image pinned by digest** (never `:latest`).
  Entrypoint, webhook env, healthcheck, Traefik routing all here. Secrets/endpoint via `.env`.
- `mkos-entrypoint.sh` → `/opt/data/mkos-entrypoint.sh` — self-heals venv deps, **asserts our
  model config** each boot (neutralizes the stock image's nexos.ai injection), hands off to the
  image entrypoint which launches `hermes gateway run` in webhook mode.
- `webhook-keeper.sh` → `/opt/mkos-watchdog/` — 1-min cron; re-registers the webhook if a restart
  window drops it (deterministic registration; no flap-war since the gateway is webhook-mode).
- `telegram-watchdog.sh` → `/opt/mkos-watchdog/` — 5-min cron; **behavioral** health (real
  synthetic webhook delivery to `:8443`, requires HTTP 200) + **auto-recovery** (`docker restart`
  on a genuine wedge) + Telegram alerts. No more false-HEALTHY.
- `mkos-watchdog.cron` → `/etc/cron.d/mkos-watchdog` — schedules the two above.
- `.env.example` — copy to `/docker/hermes-agent-bfcq/.env` and fill. **Never commit the real `.env`.**

## Deploy dir
`/docker/hermes-agent-bfcq/` on the VPS (keep the dir name — `COMPOSE_PROJECT_NAME` + volume names
depend on it). `./data` is the Hermes state volume (`/opt/data`); the bot token lives in `data/.env`.

## Bump the image (deliberately)
```
docker pull ghcr.io/hostinger/hvps-hermes-agent:latest         # inspect what moved
docker image inspect ghcr.io/hostinger/hvps-hermes-agent:latest --format '{{.RepoDigests}}'
# put the new sha256 digest in docker-compose.yml, commit, then:
cd /docker/hermes-agent-bfcq && docker compose up -d && /opt/mkos-watchdog/telegram-watchdog.sh
```

## Verify (behavioral)
```
/opt/mkos-watchdog/telegram-watchdog.sh          # expect HEALTHY (delivery-probe 200)
# then a live round-trip: send the bot a Telegram message and confirm a reply.
```

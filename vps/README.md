# VPS Hermes deployment (version-controlled)

The Hostinger VPS is the **sole Telegram gateway** (webhook mode) and hosts **central Mem0**
(Constitution §3/§5). This directory is the source of truth for that deployment so Hostinger's
`:latest` image can never silently mutate it again.

## Files
- `Dockerfile` — extends the Hostinger base image (**pinned by digest**, never `:latest`) and
  bakes in the Mem0 pgvector + Gemini deps (`psycopg[binary,pool]`, `google-genai`) at BUILD
  time. This is what makes those deps durable across `--force-recreate` / a fresh pull — no
  runtime PyPI install, no dependency on the container having internet at boot.
- `docker-compose.yml` — the gateway service, **built from the Dockerfile above** (`build:` +
  a local `image:` tag). Entrypoint, webhook env, healthcheck, Traefik routing all here.
  Secrets/endpoint via `.env`.
- `mkos-entrypoint.sh` → `/opt/data/mkos-entrypoint.sh` — checks the venv deps are present
  (normally a no-op, since the Dockerfile already baked them in; only does real work if
  something wiped them after the image build), **asserts our model config** each boot
  (neutralizes the stock image's nexos.ai injection), **starts Syncthing** (see below),
  hands off to the image entrypoint which launches `hermes gateway run` in webhook mode.
- `webhook-keeper.sh` → `/opt/mkos-watchdog/` — 1-min cron; re-registers the webhook if a restart
  window drops it (deterministic registration; no flap-war since the gateway is webhook-mode).
- `telegram-watchdog.sh` → `/opt/mkos-watchdog/` — 5-min cron; **behavioral** health (real
  synthetic webhook delivery to `:8443`, requires HTTP 200) + **auto-recovery** (`docker restart`
  on a genuine wedge) + Telegram alerts. No more false-HEALTHY.
- `mkos-watchdog.cron` → `/etc/cron.d/mkos-watchdog` — schedules the two above.
- `.env.example` — copy to `/docker/hermes-agent-bfcq/.env` and fill. **Never commit the real `.env`.**

## Syncthing (VPS → vault inbox bridge)
Lets an agent turn (any profile, triggered from Telegram or elsewhere) drop a file under
`/opt/data/Inbox/Hermes` and have it land in `Master 2.0/00-Inbox/` on the Mac/iMac for
triage (e.g. a drafted contact note — see Constitution §6 contacts convention + the
`vault-triage` skill). Folder ID `hermes-inbox`, already paired with the iMac since
2026-07-12 (config/certs live on `./data/.local/share/syncthing`, i.e. the data volume —
survives recreate). Both peers use **static Tailscale addresses**
(`tcp://100.94.185.35:22000` / `tcp://100.123.130.92:22000`), not discovery/relay, so
only that one port needs publishing (bound to the Tailscale IP, never `0.0.0.0`).
The *process* isn't part of the data volume, though — `mkos-entrypoint.sh` launches it
fresh (backgrounded, as the `hermes` user) on every boot.

**Safety config (2026-07-19, after an incident — see Constitution changelog):** a stale
Syncthing index (pre-dating the Phase 0 inbox repoint, apparently scoped to the whole
vault root at some point) caused a wave of phantom delete attempts on reconnect. No real
content was lost (verified: only `.DS_Store` files actually deleted; real vault content
sits outside the `00-Inbox` folder root Syncthing is bound to and was never reachable),
but never again by design:
- **VPS folder type is `sendonly`** (config.xml, not version-controlled — lives on the data
  volume) — the VPS only ever pushes its own new files; it can't apply or propagate a
  delete based on remote state, no matter how stale its index gets.
- **iMac folder has `ignoreDelete=true`** — the vault's inbox NEVER applies a remote-driven
  delete, from any peer, ever. This also means a VPS-side cleanup (e.g. deleting a test
  file) does NOT propagate — the inbox is now append-only from the VPS's perspective;
  removing something from it is always a local/manual/triage action on the vault side.
- If re-pairing from scratch or after another dormant period, wipe
  `./data/.local/share/syncthing/index-v2` on the VPS before restarting the process, so
  no stale index can resurface.

**One-directional in practice today:** the vault side only watches for new files; nothing
auto-files them into `Contacts/` yet — that's a manual or agent-assisted triage step.

## Deploy dir
`/docker/hermes-agent-bfcq/` on the VPS (keep the dir name — `COMPOSE_PROJECT_NAME` + volume names
depend on it). `./data` is the Hermes state volume (`/opt/data`); the bot token lives in `data/.env`.

## Bump the base image (deliberately)
```
docker pull ghcr.io/hostinger/hvps-hermes-agent:latest         # inspect what moved
docker image inspect ghcr.io/hostinger/hvps-hermes-agent:latest --format '{{.RepoDigests}}'
# put the new sha256 digest in the Dockerfile's FROM line, bump the compose `image:` tag
# date, commit, then rebuild + redeploy:
cd /docker/hermes-agent-bfcq && docker compose build && docker compose up -d \
  && /opt/mkos-watchdog/telegram-watchdog.sh
```

## Rebuild without a base bump (e.g. adding/upgrading a baked-in dep)
```
cd /docker/hermes-agent-bfcq && docker compose build --no-cache && docker compose up -d \
  && /opt/mkos-watchdog/telegram-watchdog.sh
```

## Verify (behavioral)
```
/opt/mkos-watchdog/telegram-watchdog.sh          # expect HEALTHY (delivery-probe 200)
# then a live round-trip: send the bot a Telegram message and confirm a reply.
```

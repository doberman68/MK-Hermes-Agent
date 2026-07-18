# profiles/

One `config.yaml` per production profile (`personal`, `hp`, `business`). These are deploy templates, not full profile homes — no `.env`, `auth.json`, `state.db`, sessions, or memories.

Confirmed secret-free before commit (2026-07-18): every `api_key`/`token`/`secret` field in each file is empty or a comment referencing an env var name; real credentials are supplied locally via `.env` / `auth.json`, with some fields backed by Bitwarden (see the `secrets:` block, which stores an env-var name, not a value).

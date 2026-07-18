# MK-Hermes-Agent

Shared, secret-free configuration and deploy tooling for Murat's Hermes Agent fleet (M1 Max, M3, iMac Pro, Hostinger VPS). Three production profiles: `personal`, `hp`, `business`. The `default` profile is retired (logically — see `docs/ARCHITECTURE.md`).

Governing document: `MK Personal OS Constitution.md` in the Master 2.0 Obsidian vault (`_system/`). This repo carries out that Constitution — when the two disagree, the Constitution wins and this repo should be updated to match.

## Quick start

```
scripts/bootstrap        # set up profiles on this machine from the templates in profiles/
scripts/verify            # confirm this machine matches its expected role
scripts/deploy            # pull + apply latest templates to a live install, preserving user data
```

## Layout

- `profiles/<name>/config.yaml` — deploy template for that profile. No secrets.
- `skills/` — reserved for shared custom skills; not yet populated.
- `scripts/` — bootstrap, deploy, verify.
- `docs/` — architecture pointer.

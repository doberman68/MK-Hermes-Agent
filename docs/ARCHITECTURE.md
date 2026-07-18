# MK-Hermes-Agent — Architecture Pointer

This repo holds shared, secret-free Hermes configuration templates and deploy tooling for Murat's 3-profile setup (`personal`, `hp`, `business`).

**Source of truth:** the MK Personal OS Constitution, in Master 2.0's `_system/MK Personal OS Constitution.md`. This repo implements what that document specifies — if they disagree, the Constitution wins and this repo should be updated to match.

## Layout

- `profiles/<name>/config.yaml` — profile config template. No secrets. Real API keys live in each profile's local `.env` / `auth.json` (or a secrets manager, e.g. Bitwarden), never in this repo.
- `skills/` — reserved for shared custom skills; not yet populated (see `skills/README.md`).
- `scripts/bootstrap` — set up profiles on a new/reset machine from these templates.
- `scripts/deploy` — pull latest templates and apply them to a live install, preserving user data.
- `scripts/verify` — fleet health check (profile list, gateway role, Mem0 reachability, vault path).

## default profile

`default` is retired but, on at least the M1, is not a separate profile folder — its home resolves to the root `~/.hermes` install directory (which also houses the CLI install and the other profiles' subfolders). It can't be physically archived the way `personal`/`hp`/`business` can. Retirement there is logical only: never the active/sticky profile, no cron scheduled against it. Confirm whether this same quirk holds on other machines before assuming it generalizes.

## Machines

See Constitution §3 for the authoritative machine-role table (M1 Max, M3, iMac Pro, Hostinger VPS).

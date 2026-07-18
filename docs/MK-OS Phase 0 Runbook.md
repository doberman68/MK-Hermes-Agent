---
title: MK-OS Phase 0 Runbook — Consolidation
type: runbook
status: ready
date_created: 2026-07-18
tags:
  - personal-os
  - phase-0
  - runbook
  - claude-code
---

# MK-OS Phase 0 Runbook

> **How to use:** Open a Claude Code session on the machine named in each section and paste that section (plus the Context block below) as the prompt. Run sections in order: A (M1) → B (iMac Pro) → C (VPS, via SSH from M1) → D (verification). One session per machine.

---

## Context block (paste at the top of every session)

```text
You are executing Phase 0 of Murat's MK Personal OS consolidation. Decisions already made (do not re-litigate):

- Obsidian "Master 2.0" at /Users/mkilci/Obsidian Vaults/Master 2.0 is the SOLE production vault. Master 1.0 is read-only archive.
- Hermes runs exactly 3 profiles everywhere: personal, hp, business. The "default" profile is being retired.
- The Hostinger VPS becomes the ONLY Telegram gateway and hosts a central self-hosted Mem0 (Docker, Tailscale-only).
- The iMac Pro is the always-on Apple-automation + Syncthing node. Its Syncthing inbox must point at Master 2.0, not Master 1.0.
- Business ventures (Little Pixel Company, MN-Nutra, Consulting) are sub-areas under the business profile/namespace, not separate profiles.
- Mem0 namespacing: metadata field "domain" = personal | hp | business | contacts. Business memories also get "venture" metadata.

RULES:
- NEVER delete anything. Archive or rename with a .retired suffix. Move, don't remove.
- NEVER commit secrets to Git. Credentials stay in .env / Keychain / 1Password.
- Before changing any running service, capture its current state (config file copy + `launchctl list` output) into a dated backup folder.
- Verify every change before declaring it done. Report what you actually observed, not what you expected.
- If reality differs from what this runbook assumes (paths, versions, profile names), STOP and report the difference before proceeding.
```

---

## Section A — M1 Max (primary workstation)

### A1. Snapshot current state

- Record: `hermes --version` (or equivalent), profile list, gateway status, active config paths, `launchctl list | grep -i hermes`.
- Copy all Hermes config files to `~/MK-OS-Backups/2026-07-18-pre-phase0/`.

### A2. Stop the M1 gateway as an always-on service

- The M1 currently runs the `personal` gateway under launchd. Unload it so the M1 is interactive-only (the VPS becomes the sole gateway in Section C).
- Keep the Hermes CLI/desktop fully working for interactive use.
- Do NOT delete the launchd plist — move it to the backup folder.

### A3. Normalize profiles

- Confirm `personal`, `hp`, `business` exist and are correctly configured.
- Rename/retire `default` (archive its config; migrate anything unique into the right profile).
- Fix the known memory drift: ensure the `personal` CLI profile is configured for Mem0 (currently it reports built-in memory only while desktop reports Mem0). For now point at the existing Mem0 setup; Section C will repoint everything to the central VPS instance.

### A4. Create/verify the MK-Hermes-Agent repo

- Private GitHub repo `MK-Hermes-Agent` (owner: doberman68).
- Structure: `profiles/` (shared config templates, no secrets), `skills/`, `scripts/bootstrap`, `scripts/deploy`, `scripts/verify`, `docs/`.
- Commit the normalized 3-profile configuration (secrets stripped, referenced via env vars).
- Write `scripts/verify` to check on any machine: profile list matches, gateway state matches that machine's role, Mem0 endpoint reachable, vault path correct.

### A5. Vault changes (Master 2.0)

- Create the `3-Business/` PARA tree:
  `@1 Projects/`, `@2 Areas/Little Pixel Company/`, `@2 Areas/MN-Nutra/`, `@2 Areas/Consulting/`, `@3 Resources/`, `@4 Archives/`.
- File `MK Personal OS Constitution.md` into `_system/`.
- Add a changelog entry to the vault's structural changelog noting the new tree.
- Update the contact template in `_templates/` to the new frontmatter convention (`domains:` multi-value list + `relationship:` field). Do NOT mass-migrate existing contacts yet — that's a later phase.

### A6. Tailscale

- Tailscale is installed but was found stopped. Start it, enable on login, confirm the M1 appears in the tailnet.

---

## Section B — iMac Pro (always-on Apple node)

### B1. Snapshot current state

- Same as A1: Hermes state, launchd jobs, Syncthing config, cron jobs (`gpt-5.6-luna` on `default` profile, 2 scheduled jobs expected).
- Back up to `~/MK-OS-Backups/2026-07-18-pre-phase0/`.

### B2. Repoint Syncthing (URGENT — active data loss)

- Current shared folder: `/Users/mkilci/Obsidian Vaults/Master 1.0/-INBOX Hermes` (folder ID `hermes-inbox`).
- Repoint to: `/Users/mkilci/Obsidian Vaults/Master 2.0/00-Inbox/` (coordinate the folder change on the VPS side in Section C — both ends must agree).
- Move any stranded items sitting in the Master 1.0 inbox into `Master 2.0/00-Inbox/` with a `migrated-from-1.0` note.
- Confirm sync works end-to-end with a test file.

### B3. Migrate cron jobs off `default`

- Move the two scheduled jobs (daily 5 PM pickleball weather; monthly vehicle maintenance check) to the `personal` profile.
- Retire the `default` profile per A3.

### B4. Demote the iMac gateway

- The iMac currently runs an active Hermes gateway with Telegram. After the VPS gateway is live (Section C), stop Telegram on the iMac to avoid dual-gateway message races.
- The iMac KEEPS: Syncthing, Apple-specific launchd automations, and (later) the full-screen MK OS dashboard.
- Sequencing: do B4 LAST, after C3 confirms the VPS gateway is receiving Telegram traffic.

### B5. Tailscale

- Install/enable Tailscale; confirm the iMac joins the tailnet.

---

## Section C — Hostinger VPS (via SSH from the M1 session)

### C1. Snapshot current state

- Inventory running services: Hermes components, Web UI, Syncthing, Docker containers, cron. Record to the backup folder on the M1.

### C2. Deploy central Mem0

- Docker Compose: Mem0 OSS + its vector store (Qdrant or pgvector — pick based on what's already on the box).
- Bind to the Tailscale interface ONLY (no public exposure). API key auth on top.
- Configure the single user identity `murat`; document the metadata convention: `domain` (personal|hp|business|contacts) + `venture` (little-pixel|mn-nutra|client-slug) for business memories.
- Migrate existing Mem0 data from the current setup into this instance (export → import; verify counts).
- Then repoint every Hermes profile on every machine (M1, M3, iMac, VPS) at this endpoint. Same user ID everywhere; distinct agent/machine identifiers.

### C3. Make the VPS the sole Telegram gateway

- Configure the Hermes gateway here with the 3-profile model, Telegram connected.
- Test: send a Telegram message, confirm the VPS answers.
- Only then execute B4 (stop iMac Telegram).

### C4. Syncthing counterpart

- Update the VPS side of the `hermes-inbox` share: `/opt/data/Inbox/Hermes` ↔ `Master 2.0/00-Inbox/` (matching B2).

### C5. Tailscale + hygiene

- Confirm Tailscale up; close any public ports that Tailscale now makes unnecessary.
- Verify disk space, Docker restart policies (`unless-stopped`), and that everything survives a reboot (`docker compose` + systemd).

---

## Section D — Fleet verification (run last, from the M1)

Run `scripts/verify` (built in A4) against every node, or check manually:

- [ ] Exactly one Telegram gateway responds (VPS). M1/iMac gateways off.
- [ ] All machines: 3 profiles (`personal`, `hp`, `business`); `default` retired everywhere.
- [ ] All profiles on all machines report the SAME Mem0 endpoint (VPS) and user ID.
- [ ] Memory round-trip: store a fact from the M1 `personal` profile, recall it from Telegram (VPS). Store from iMac, recall from M1.
- [ ] Namespace isolation: a `business` memory is NOT recalled in a `personal` context; `contacts` IS readable from all profiles.
- [ ] Syncthing: file dropped in VPS inbox appears in `Master 2.0/00-Inbox/` on the iMac (and nothing writes to Master 1.0).
- [ ] Cron: pickleball + vehicle jobs fire from `personal` profile via VPS/iMac as configured.
- [ ] Tailscale: all four nodes visible in the tailnet; Mem0 unreachable from the public internet.
- [ ] `MK-Hermes-Agent` repo: clean clone + `scripts/bootstrap` works on the M3 (this doubles as the M3's setup — its clean-validation role).
- [ ] Backups: pre-change state archived on the M1; note added to vault changelog.

**Phase 0 exit criterion:** every check above passes, and the Constitution in `_system/` matches deployed reality.

---

## Known unknowns to capture during execution

- Exact Hermes CLI commands for profile/gateway management (discover on-box; versions: M1 v0.18.2).
- Whether current Mem0 is cloud-hosted or local (affects C2 migration path).
- M3 current state (not yet inspected — bootstrap it fresh from the repo in D).
- Master 2.0 whole-vault sync authority decision (Obsidian Sync recommended) — record the choice in the Constitution §8 and changelog.

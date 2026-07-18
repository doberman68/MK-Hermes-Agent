---
title: MK Personal OS Constitution
type: constitution
status: active
version: 1.0
date_created: 2026-07-18
date_updated: 2026-07-18
location: _system/
tags:
  - personal-os
  - constitution
  - governance
  - architecture
---

# MK Personal OS Constitution

> **Purpose:** This document is the single source of truth for how Murat's systems fit together. Every tool, machine, agent, and workflow has exactly one owner defined here. When a new tool or workflow is considered, it must be checked against this document. If it conflicts, either the tool is rejected or this Constitution is deliberately amended (with a changelog entry).

> **Prime directive:** One authority per data type. No system may silently compete with another for the same information.

---

## 1. Core principles

- **One source of truth per data type.** Duplication is allowed only as backup, never as a second live authority.
- **Hermes executes; it does not own data.** Hermes is the operator. Canonical data lives in Obsidian, Mem0, Calendar, or GitHub.
- **Local-first, cloud-assisted.** Markdown and ordinary files remain usable without any AI layer.
- **Profiles enforce domain boundaries.** Personal, HP, and Business contexts never silently contaminate one another.
- **Search before duplication.** Find existing information before creating another copy.
- **Archive, never delete.** Destructive operations require explicit approval.
- **No secrets in Obsidian or Git. Ever.** Secrets live in 1Password / Keychain / environment files.
- **Every new feature is guilty until it proves measurable time savings or reduced cognitive load.**

---

## 2. System ownership table

| Responsibility | Owner | Must NEVER own |
|---|---|---|
| Durable knowledge, projects, people, research | **Obsidian Master 2.0** | Secrets, calendar alerts, shared LPC ops data |
| Semantic AI memory (facts, preferences, context) | **Mem0 (self-hosted, VPS)** | Long-form documents, project files |
| Daily execution + lightweight reminders | **Apple Reminders** | Detailed project tasks with context |
| Project tasks with context | **Obsidian** (`📅 YYYY-MM-DD` format + `Upcoming.md`) | Calendar events |
| Time, appointments, alerts | **Calendar** | Notes, preparation context |
| Agent config, skills, deploy scripts | **Private GitHub repo `MK-Hermes-Agent`** | Credentials, personal documents |
| Conversation history | **Hermes session database** | Durable knowledge (promote to Obsidian) |
| Little Pixel shared operations (suppliers, databases) | **Notion** | Murat's personal LPC notes (those go to Obsidian) |
| HP work documents | **Microsoft 365 / OneDrive** | Personal or business content |
| Personal documents | **iCloud Drive** | HP corporate files |
| Photography catalog | **Lightroom Classic** | — |
| Backup (local) | **Synology NAS** | Live editing / runtime data |
| Backup (offsite) | **Backblaze** | — |
| Secure network fabric | **Tailscale** | — |
| Secrets | **1Password / Keychain / Yubico** | — |
| Mobile AI command | **Telegram → Hermes** | Canonical storage (chat is an interface, not an archive) |

---

## 3. Machine roles

| Machine | Role | Runs |
|---|---|---|
| **M1 Max MacBook Pro (64 GB)** | Primary workstation. MK OS development, Obsidian editing, Lightroom, local AI (Ollama), Claude Code sessions | Interactive work only — no always-on gateway |
| **M3 Mac** | Mobile/secondary workstation, clean validation node for profile portability and MK OS onboarding tests | Interactive work only |
| **iMac Pro (Intel Xeon, 64 GB)** | Always-on Apple-automation node: Syncthing, Hazel-style routing, full-screen MK OS dashboard display, Apple-app-dependent scheduled jobs | launchd jobs, Syncthing. NOT the Telegram gateway. NOT a local-LLM node (Intel) |
| **Hostinger VPS** | Always-on remote brainstem: Telegram gateway (sole), Hermes cron, webhooks, **central Mem0 service**, long-running automations | Docker: Mem0. Hermes gateway. Tailscale-only access |
| **Windows device** | HP work compatibility, Copilot+ demos, Microsoft ecosystem validation | Corporate-managed |
| **iPhone / iPad** | Capture, Telegram command, Reminders, vault review | — |
| **Synology NAS** | Backup and archive tier only | Never a live-sync writer to working folders |

---

## 4. Hermes profiles

Exactly **three** production profiles, identical on every machine, deployed from `MK-Hermes-Agent`:

| Profile | Scope |
|---|---|
| `personal` | Life, family, photography, pickleball, vehicles, home projects, personal research, job search |
| `hp` | HP Inc. work only: customer briefings, AI PC content, HP branding, enablement |
| `business` | ALL personal business ventures (see 4.1) |

- The `default` profile is **retired** on all machines. Its cron jobs (pickleball weather, vehicle maintenance) migrate to `personal`.
- Profiles are organized by **mental operating mode**, not by company. Ventures are folders and namespace metadata, not new profiles.
- **`default` retirement caveat (M1, confirmed 2026-07-18):** on Hermes v0.18.2, `default` is not a peer profile folder — its home path resolves to the root `~/.hermes` install directory, which also houses the CLI install and the other three profiles' subfolders. It cannot be physically archived/renamed like `personal`/`hp`/`business` without breaking the install. Retirement here means logical only: `active_profile` is never set to `default`, nothing schedules against its cron store, and it is never surfaced as a usable profile in practice. Verify this same constraint on other machines before assuming it generalizes.

### 4.1 Business ventures (sub-areas under `business`)

| Venture | What it is | Notes |
|---|---|---|
| **Little Pixel Company** | Wife's gift business: laser cutting, engraving, CNC, UV printing | Shared ops in Notion; Murat's own notes in Obsidian |
| **MN-Nutra** | Consulting for nephew's supplement company | |
| **Consulting (general)** | Future clients (chiropractor, etc.) | One folder per client as they arrive |

---

## 5. Memory architecture (Mem0)

- **One Mem0 instance**, self-hosted in Docker on the Hostinger VPS, reachable only over Tailscale. One user identity (`murat`) across every machine and agent.
- **Namespaces via metadata `domain` field:** `personal` / `hp` / `business` / `contacts`.
- `contacts` is a **shared namespace readable by all profiles** — people cross domains.
- Business ventures share the `business` namespace for now, tagged with a `venture` metadata field (`little-pixel`, `mn-nutra`, client slug). **Split rule:** the day a client-confidentiality conflict appears, that venture gets its own namespace. The metadata tagging makes this migration cheap.
- Each Hermes profile reads/writes only its own domain + `contacts`.
- **Decision record:** Mem0 chosen over Honcho (2026-07) — maturity, Apache 2.0 license, published benchmarks, lighter stack, broad SDK support. **Revisit Honcho: January 2027.**

### What goes where

| Information | Home |
|---|---|
| "Murat prefers concise, structured answers" | Mem0 (`personal`) |
| "LPC's UV printer supplier is X" (shared ops) | Notion |
| "Tip from YouTube on laser settings" | Obsidian `3-Business/Little Pixel/` |
| Detailed meeting/project/research content | Obsidian |
| How-to procedures for agents | Hermes skills (GitHub) |
| Credentials | 1Password / Keychain — never Mem0, Obsidian, or Git |

---

## 6. Obsidian vault law

| Vault | Status |
|---|---|
| **Master 2.0** | **PRODUCTION.** Sole live vault |
| Master 1.0 | Read-only historical archive and migration source |
| Master 3.0 (tech girl) | Experimental sandbox; ideas promote INTO 2.0, never a parallel production vault |
| MK AI WIKI | Specialized AI corpus; relationship to `0-Wiki` to be formalized (open item) |

### Structure addition

Add a third PARA tree to Master 2.0:

```text
3-Business/
├── @1 Projects/
├── @2 Areas/
│   ├── Little Pixel Company/
│   ├── MN-Nutra/
│   └── Consulting/
├── @3 Resources/
└── @4 Archives/
```

### Contacts convention

- One top-level `Contacts/` folder. **No domain subfolders.**
- Domains identified in YAML frontmatter, multi-value:

```yaml
---
type: contact
domains: [hp, personal]          # or [business/little-pixel], [business/mn-nutra], etc.
relationship: colleague           # colleague | client | supplier | family | friend | pickleball | recruiter
company: "[[HP Inc]]"
---
```

- Dataview builds per-domain contact indexes from `domains`. Hermes and Mem0 filter on the same field.

---

## 7. Task law

- **Obsidian** owns project tasks, in context, format: `- [ ] Description 📅 YYYY-MM-DD`, surfaced in `Upcoming.md`.
- **Apple Reminders** owns lightweight, shared, and location-based reminders (groceries, family lists, quick captures).
- **Calendar** owns anything with a time and an alert.
- **Hermes cron** owns recurring automated system tasks.
- **NotePlan is shelved** (liked, may return — re-adding requires a Constitution amendment).
- **Banned:** Todoist, Things 3, or any new task manager without amendment. Never maintain a duplicate manual master task list.

---

## 8. Sync law

**One live-sync authority per dataset.** Never point two bidirectional sync systems at the same folder.

| Dataset | Sync authority |
|---|---|
| Master 2.0 vault | ONE chosen mechanism (Obsidian Sync recommended for multi-device smoothness) — decide in Phase 0, document here |
| Hermes handoff inbox (VPS ↔ Mac) | Syncthing, narrow folder only: `Master 2.0/00-Inbox/` — **never** full-vault |
| Skills / config / scripts | Git (`MK-Hermes-Agent`) |
| HP files | OneDrive |
| Personal files | iCloud |
| Backup | Synology (local) + Backblaze (offsite); pull-based, never a live writer |

---

## 9. Security law

- Tailscale on all infrastructure (Macs, VPS, NAS). No public ports for personal services.
- Tailnet identity: personal Google account (mkilci1@gmail.com) — never the HP identity. The HP Windows device stays OFF the personal tailnet.
- MagicDNS + HTTPS certs enabled; Mem0, dashboard, and admin surfaces are tailnet-only.
- Mem0 and MK OS dashboard reachable via Tailscale only.
- Active-profile visibility before any agent action; HP content never leaves HP contexts without deliberate approval.
- External side effects (send, post, delete, config change) require approval and produce an audit record.
- 3-2-1 backup: local working copy → Synology → Backblaze. Quarterly restore test — a backup is not valid until a restore succeeds.

---

## 10. AI platform routing

| Platform | Role |
|---|---|
| **Hermes** | Front door. Anything touching files, memory, automations, or multiple tools |
| **Claude Code** | Repository, coding, filesystem-heavy project work (one session per machine) |
| **Claude / Cowork** | Long-form analysis, documents, strategy, mobile-accessible planning |
| **ChatGPT / Codex** | Model provider inside Hermes; direct use for specialist/multimodal tasks |
| **Perplexity** | Fast cited research |
| **Ollama / LM Studio** | Local, private, offline inference (M1 Max only) |
| **Copilot** | HP/Microsoft work surface |

No AI tool may become a separate long-term memory silo. Durable outcomes are written back to Obsidian; context facts to Mem0.

---

## 11. Open items

- [ ] Choose the Master 2.0 whole-vault sync authority (Obsidian Sync vs alternative) — Phase 0
- [ ] Formalize MK AI WIKI ↔ `0-Wiki` relationship
- [ ] M3 exact specs; benchmark vs M1 Max before any role change
- [ ] Synology model, capacity, snapshot policy documentation
- [ ] Replacement voice-capture pipeline (Plaud returned) — evaluate Superwhisper-centric flow
- [ ] Honcho re-evaluation: January 2027
- [ ] NotePlan re-evaluation: only by amendment

---

## 12. Changelog

| Date | Version | Change |
|---|---|---|
| 2026-07-18 | 1.0 | Initial Constitution. Master 2.0 declared production. Three-profile model. Central Mem0 on VPS. NotePlan shelved. Todoist retired. Contacts frontmatter convention adopted. |
| 2026-07-18 | 1.1 | Tailnet identity decided: personal Google (mkilci1@gmail.com). HP Windows device excluded from tailnet. MagicDNS + HTTPS enabled. |
| 2026-07-18 | 1.2 | Phase 0, Section A (M1) executed: personal gateway launchd job unloaded (plist archived, not deleted); confirmed `default` profile's home is the root `~/.hermes` install dir, not a peer folder — retirement is logical-only (see §4 caveat); stray "Pickleball weather check test" cron job moved from root/default's cron store to `personal`'s; fixed the known Mem0 drift by setting `memory.provider: mem0` in `profiles/personal/config.yaml` (was empty string, falling back to built-in memory). |
| 2026-07-18 | 1.3 | Phase 0, Section A continued: `MK-Hermes-Agent` repo scaffolded locally (profiles/ config templates — secret-scanned clean, scripts/bootstrap|deploy|verify, docs/) and committed (`809ba0d`); push to origin blocked on this machine by missing GitHub credentials, pending manual auth setup. `3-Business/` PARA tree created in the vault; contact template (`_templates/person.md`) updated to the `type: contact` + `domains:`/`relationship:` convention (existing contacts not migrated). Tailscale found already running and M1 already in the tailnet as `m1` (contrary to runbook's "stopped" assumption) — `TailscaleStartOnLogin` was 0; enabled it. Observation for Section C: local `mem0.json` has no `base_url`/host field, only an `api_key` — suggests the current Mem0 setup is the cloud-hosted API, not self-hosted (resolves one of the Constitution's §11 open items in advance). |

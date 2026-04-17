# Audos Workspace DB — Table Ownership & Cleanup Analysis

**Date**: 2026-04-17 (updated after Otto Q10 response)  
**Purpose**: Classify all 20 tables — what to keep, what to drop, what needs Kane's decision.

---

## Key Architectural Facts (confirmed by Otto Q10–Q12)

> **The Audos platform does NOT auto-provision any tables in workspace schemas.** Every table in `ws_8f1ad824_832f_4af8_b77e_ab931a250625` was created by Otto during a conversation, or by a platform feature when Kane used it. The workspace schema is entirely app-scaffold. The Audos platform's own infrastructure tables (`funnel_contacts`, `funnel_events`, `ad_campaigns`, `workspaces`, etc.) live in a **separate platform DB** — not in the workspace schema at all.

> **Only one platform feature writes to a workspace table: Lead Scout → `app_outreach_leads`.** All other Audos platform features (analytics, CRM, ads, payments, carousel, boosters, voiceover, video) use the platform DB — they have no workspace tables and cannot be broken by workspace schema changes.

> **`app_outreach_leads` is user-triggered, not Audos-managed.** Lead Scout runs when Kane asks Otto to find leads. Audos does not write here for its own business purposes. If the table is dropped, Lead Scout recreates it automatically on next use — dropping it loses only the stored rows, not the feature.

---

## Final Classification

### LEAD SCOUT TABLE — Drop or keep (Kane's call)

| Table | Rows | Notes |
|---|---|---|
| `app_outreach_leads` | 11 | Lead Scout writes here when Kane asks Otto to scout leads. 11 rows from one March 18 run — podcast production agencies as Throughline prospects, all `drafted`, emails never unlocked. Otto confirmed: dropping it loses only these rows; Lead Scout recreates the table on next use. |

Options: **Drop** (clean slate, Lead Scout still works), **Keep** (preserve the 11 drafted leads), or **Truncate** (wipe stale rows, keep table structure).

---

### DEPRECATED — Safe to DROP (clearly dead, daemon supersedes)

All created by Otto as scaffolding for Audos-built apps that are now fully replaced by the daemon.

| Table | Rows | What it was for |
|---|---|---|
| `app_briefing_podcast_profiles` | 0 | Briefing app — podcast show config |
| `app_briefing_research_sessions` | 0 | Briefing app — guest research + RoS |
| `app_briefing_ros_versions` | 0 | Briefing app — run-of-show version history |
| `app_guest_prep_podcast_profiles` | 1 | Guest Prep app — duplicate podcast config (1 stale SG2GG row) |
| `app_guest_prep_research_sessions` | 0 | Guest Prep app — research per guest |
| `app_guest_prep_ros_versions` | 0 | Guest Prep app — run-of-show version history |
| `app_podcast_setup_profiles` | 0 | Onboarding wizard — show setup |
| `app_studio_episodes` | 0 | Studio app — episode tracking |
| `app_studio_content` | 0 | Studio app — social content per episode |
| `app_studio_generated_content` | 0 | Studio app — generated copy |
| `app_studio_time_tracking` | 0 | Studio app — time-saved metrics (vanity) |

**Count**: 11 tables, 1 data row.

---

### DROP — App-scaffold, confirmed safe by Otto (Q11)

Otto confirmed no active Audos platform feature reads from any of these. The only code that read them was the deprecated Throughline mini-apps (Briefing, Studio, Signature) — all superseded by the daemon.

| Table | Rows | Otto confirmation |
|---|---|---|
| `app_speakers` | 3 | No platform reads. Created for transcript parsing in old apps. |
| `app_voice_profiles` | 2 | No platform reads. Created for Signature concept, untrained, never connected to platform voice features. |
| `app_voice_refinements` | 0 | No platform reads. Training loop that was never implemented. |
| `app_dashboard_activity` | 2 | No platform reads. Activity feed feature in old dashboard app. |
| `app_reels` | 1 | No platform reads. Studio app only. |
| `app_reel_captions` | 0 | No platform reads. Paired with app_reels. |
| `app_generated_captions` | 0 | No platform reads. Empty. |
| `app_linked_references` | 2 | No platform reads. URL cache from Briefing/Guest Prep only. |

**Count**: 8 tables.

---

## Summary

| Category | Count | Tables |
|---|---|---|
| Kane's call — Lead Scout feature table | 1 | `app_outreach_leads` (drop or keep; feature survives either way) |
| Drop — deprecated app tables | 11 | briefing_*, guest_prep_*, podcast_setup, studio_* |
| Drop — app-scaffold, confirmed safe (Otto Q11) | 8 | speakers, voice_*, dashboard_activity, reels, reel_captions, generated_captions, linked_references |
| **Total confirmed drops** | **19** | Everything except `app_outreach_leads` |

After cleanup: workspace schema contains only `app_outreach_leads` (or zero tables if that's dropped too). No other Audos platform feature has a workspace table.

---

## DROP SQL (ready to run)

**NOTE**: Otto's example SQL omits the `app_` prefix — his SQL would fail. All table names in the actual DB include `app_`. The corrected SQL below is verified against the live schema.

```sql
-- Full workspace cleanup — drops all 19 app-scaffold tables.
-- Leaves only app_outreach_leads (Lead Scout / platform-active).
-- Confirmed safe by Otto Q8, Q10, Q11 (2026-04-17).

DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_briefing_podcast_profiles;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_briefing_research_sessions;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_briefing_ros_versions;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_guest_prep_podcast_profiles;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_guest_prep_research_sessions;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_guest_prep_ros_versions;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_podcast_setup_profiles;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_studio_episodes;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_studio_content;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_studio_generated_content;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_studio_time_tracking;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_speakers;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_voice_profiles;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_voice_refinements;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_dashboard_activity;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_reels;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_reel_captions;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_generated_captions;
DROP TABLE IF EXISTS ws_8f1ad824_832f_4af8_b77e_ab931a250625.app_linked_references;
```

---

## What this means for Atlas

Atlas manages the **daemon's Postgres** — not the Audos workspace DB. These are two separate databases. Atlas does not touch anything in the Audos schema.

Once the Audos workspace is cleaned up:
- **Audos workspace DB**: `app_outreach_leads` only (Lead Scout managed). All else is ours to drop.
- **Daemon DB (throughline_*)**: episodes, contacts, communications, arc, research, sources — Throughline-owned, Atlas-managed.

New tables in the workspace schema (e.g., `ext_episode_sources`) go here only if there's a reason to co-locate with Audos data. Currently no such reason exists — the daemon DB is the right home for Throughline-specific relational data.

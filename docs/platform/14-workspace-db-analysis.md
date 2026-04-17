# Audos Workspace DB — Full Analysis

**Date**: 2026-04-17
**Schema**: `ws_8f1ad824_832f_4af8_b77e_ab931a250625`
**Connection**: DigitalOcean Postgres 18.3

---

## What's in the database (row counts)

| Table | Rows | Status |
|---|---|---|
| `app_outreach_leads` | 11 | Active — draft cold emails to podcast production companies |
| `app_speakers` | 3 | John Gonzales (host), SG2GG (brand), Jess Thorne (guest) |
| `app_voice_profiles` | 2 | John + SG2GG brand — both untrained (0 samples) |
| `app_dashboard_activity` | 2 | API test events from 2026-03-31 |
| `app_linked_references` | 2 | Two fetches of trythroughline.com (both 0 content_length — empty) |
| `app_guest_prep_podcast_profiles` | 1 | Full SG2GG podcast config |
| `app_reels` | 1 | "Why DonorsChoose Exists" — Jess Thorne, status: draft |
| All other tables | 0 | Briefing, Studio, Captions, RoS versions — never used |

---

## Finding 1: The outreach leads are B2B sales prospects, not podcast guests

The 11 rows in `app_outreach_leads` are podcast **production companies** — agencies, boutique editors, freelance producers — not guests for SG2GG. Audos generated these as sales leads for Throughline.

All 11 share one `outreach_batch_id` (`373a0438-5b9b-4901-a078-3b9f4646b482`), all have `status = 'drafted'`, all have `email_not_unlocked@placeholder.com` (email unlock is a paid feature of Audos's outreach tool).

| Rank | Name | Title | Company | Score |
|---|---|---|---|---|
| 1 | Amy | Founder, Executive Producer | Critical Frequency | 95 |
| 2 | Hayleigh | Founder, Podcast Producer + Strategist | Espresso Podcast Production | 95 |
| 3 | Katharine | Owner/Producer/Editor | The Podcast Shop | 90 |
| 4 | Hewitt | Founder, Podcast Producer | Amygdala Media | 90 |
| 5 | Drew | CEO, Podcast Producer | Williams Media | 88 |
| 6 | Matthew | Host, Producer, Co-Creator | The Hyper Space | 85 |
| 7 | Renata | Host & Founder | Studio rdn-x | 85 |
| 8 | Pat | Co-Founder, Podcast Producer | Sundial Media | 85 |
| 9 | George | Host/Producer/Sales | TogiNet | 82 |
| 10 | Steve | Creative Director / Podcast Producer | Vandalpop Media | 80 |
| 11 | Fatjona | Founder & Host | Independent Production | 78 |

Each row includes a full draft cold email in `notes`, personalized to the company. The AI reason logic correctly frames each as a prospect for Throughline's workflow efficiency pitch.

**Implication**: These are NOT in conflict with the Throughline `contacts` table (which holds SG2GG podcast guests). They serve a different purpose entirely — Throughline marketing/sales. The two tables should stay separate; the Throughline contacts table should not try to sync with this.

**Action for Kane**: To actually send these, email addresses need to be unlocked through the Audos outreach tool (paid feature), or the names+companies need to be looked up manually. LinkedIn URLs are populated for most.

---

## Finding 2: Audos has a duplicate of the podcast config — source of truth is ambiguous

`app_guest_prep_podcast_profiles` has one row: a full SG2GG profile equivalent to what Throughline daemon stores in `podcast_config`.

**Audos record (from live DB):**
- `podcast_name`: So Good to Grow Good
- `target_audience`: Mission-driven leaders, social entrepreneurs, nonprofit executives, sustainability advocates, and founders building impact-driven organizations. Primarily professionals in their 30s–50s interested in social enterprise, environmental sustainability, and scaling solutions that matter.
- `style`: Storytelling
- `tone`: Friendly
- `themes_goals`: Social entrepreneurship, environmental sustainability, scaling impact-driven organizations, mission preservation during growth, community-based solutions, equitable business practices, innovation in clean tech and circular economy. Listeners should take away actionable insights, fresh inspiration, and a deeper understanding of how to scale solutions that matter without losing their mission.
- `standard_questions`: 5 signature questions (the SG2GG arc anchors)

This mirrors `podcast_config` in the daemon but has diverged — the daemon now has arc templates, scorecard templates, research templates, and intro/outro templates that don't exist in Audos. Audos has `standard_questions` as raw text; the daemon has structured arc_template with typed sections.

**Decision needed**: Audos's podcast profile is effectively read-only from Throughline's perspective. The daemon is the source of truth. These can coexist; Audos's version is what its own apps (Briefing, Guest Prep) use. No sync needed — they serve different workflows.

---

## Finding 3: Voice profiles exist but are empty

Two voice profiles: `John Gonzales` (host) and `So Good to Grow Good` (brand). Both have `sample_count = 0` and `is_trained = false`.

The voice profile infrastructure is in place in Audos. The Throughline Signature feature (writing in Kane's voice for social content) depends on training these. As of 2026-04-17, no samples have been uploaded.

**Action**: Voice training in Audos requires uploading audio samples through the Audos UI. This is separate from anything Throughline can trigger via the AI hook API.

---

## Finding 4: Only one episode has any Audos-side data

`app_reels`: one row — "Why DonorsChoose Exists" featuring Jess Thorne (from the SG2GG podcast). Status: draft. No transcript in the DB (column is NULL). Created 2026-03-10.

This was likely created manually via the Audos Studio app, not generated through the Throughline workflow. It predates the current Throughline episode pipeline and the contacts migration.

No research sessions, no run-of-show versions, no captions exist. The Briefing and Studio features have never been used in production.

---

## Finding 5: The Briefing and Studio apps are entirely unused

All these tables are empty:
- `app_briefing_podcast_profiles` — Briefing app's show config
- `app_briefing_research_sessions` — Briefing app guest research
- `app_briefing_ros_versions` — Briefing app run-of-show
- `app_generated_captions` — Caption generation
- `app_guest_prep_ros_versions` — Guest Prep run-of-show
- `app_podcast_setup_profiles` — Onboarding wizard
- `app_reel_captions` — Reel caption content
- `app_studio_content` — Studio social content
- `app_studio_episodes` — Studio episode tracking
- `app_studio_generated_content` — Studio generated copy
- `app_studio_time_tracking` — Studio time-saved metrics
- `app_voice_refinements` — Voice refinement history

All of this workflow now lives in Throughline. The daemon handles research, arc generation, prep emails, and content pipelines. Audos's own apps (Briefing, Guest Prep, Studio) for these workflows have never been used.

---

## Schema structure observations

- All tables use integer PKs (not UUIDs) — auto-increment. FKs that reference other tables sometimes use UUIDs (`research_session_id uuid`, `episode_id uuid`) — this FK type mismatch (integer PK, uuid FK) suggests schema was built incrementally.
- Multi-tenancy via `session_id` + `user_id` + `org_id` triple. Not all tables have all three — some only have `session_id`.
- `jsonb` is used sparingly: `metadata` in `app_dashboard_activity`, `long_form_samples` in `app_voice_profiles`, `learned_patterns` in `app_voice_refinements`.
- No foreign key constraints enforced in the schema — all FKs are logical/documentation-only.
- `created_at` / `updated_at` timestamps without timezone — not UTC-explicit.

---

## Write permissions (to be confirmed with Otto)

The DB role `ws_dev_8f1ad824832f4af8b77e` was generated as a dev credential. We have not tested `CREATE TABLE` or `INSERT`. Assume read/write on existing tables; table creation needs confirmation.

---

## Summary for Throughline product decisions

| Question | Answer from data |
|---|---|
| Should we sync contacts with app_outreach_leads? | No — different populations (B2B sales vs. podcast guests) |
| Is Audos the source of truth for podcast config? | No — daemon is. Audos's copy is stale. |
| Can we use app_speakers for guest management? | No overlap — app_speakers only has John + brand + one guest. Daemon contacts table is the right home. |
| Should we create tables in this schema? | Blocked on convention confirmation (need Otto). |
| Is voice training data available here? | Schema yes, data no — profiles are empty. |
| Which Audos apps does Kane actually use? | None of the workflow apps. Throughline has replaced Briefing, Guest Prep, and Studio entirely. |

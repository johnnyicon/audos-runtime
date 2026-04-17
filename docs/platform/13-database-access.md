# Audos Database Access

**Status**: In discovery — feature surfaced in the Audos Developer UI but credential generation fails with "Workspace not found" on workspace `ws_351699` as of 2026-04-16.

## What it is (per Audos UI)

The Audos Developer panel exposes a **Database Access** card:

> **Database Access**
> Direct PostgreSQL access to your workspace's data schema for local development.
>
> Generate a scoped PostgreSQL role that can only access your workspace's schema (`ws_351699`). Use it with pgAdmin, TablePlus, or any standard PostgreSQL client.
>
> [ Generate Credentials ]

**Key claims:**
- Direct PostgreSQL access (not HTTP wrapper)
- Scoped to workspace schema (`ws_<workspace-id>`)
- Read/write to the workspace's data schema
- Compatible with any standard PostgreSQL client
- Positioned as a local-development affordance

## Observed behavior (2026-04-16)

Clicking "Generate Credentials" in the Developer panel of the Audos app returns a toast error:

> **Error**
> Workspace not found

No credentials are generated. The panel doesn't show any state change.

## Diagnosis in flight

**API path**: unknown. Blind probes of likely URL patterns all return `"API route not found"` (a generic 404 from the API router), which is a distinct error from the "Workspace not found" that the UI surfaces. This means:
- The UI knows the correct endpoint path.
- The endpoint exists on the server.
- The server-side workspace lookup fails specifically for `351699`.

Probed patterns that 404'd (these are NOT the real endpoint):
- `/api/workspaces/:id/database-credentials`
- `/api/workspace/:id/database-credentials`
- `/api/workspaces/:id/credentials`
- `/api/database/credentials`
- `/api/developer/database-credentials`
- `/api/dev/database`
- `/api/credentials/generate`
- `/api/hooks/execute/workspace-:id/database`

## Hypotheses for "Workspace not found"

1. **Provisioning gap**: Audos hasn't provisioned the per-workspace Postgres role for `ws_351699` yet. The feature is visible in the UI but back-end infra isn't in place for this workspace. Audos would need to run the provisioning step for Kane's workspace.
2. **ID mismatch**: The credential-generation endpoint expects a UUID workspace identifier (mirroring the AI hook which uses `workspace-351699` in the URL but may use a different ID internally), and the numeric `351699` doesn't resolve.
3. **Session / auth**: The UI sends a session token whose workspace claim differs from the one the UI shows. A logout/login might refresh it.
4. **Feature-flag state**: The feature is UI-enabled for Kane's workspace but not back-end-enabled.

## Next step to narrow it down (DevTools)

When convenient, Kane can:
1. Open the Audos app
2. Open browser DevTools → Network tab
3. Click **Generate Credentials**
4. Find the failing request (likely `POST` to something under `/api/`)
5. Capture the request URL, request body, and response body

That pinpoints the real endpoint path + the exact server error payload, and we can then either:
- File a targeted bug report with Audos (with the endpoint + response)
- Work around with a direct DB connection if the infra is actually there

## What we'd use this for

Assuming the feature works once unblocked:

- **Inspect workspace data directly** — see what Audos stores in `ws_351699` beyond what the hook API exposes
- **Local-dev read replica** — point local tools at the workspace data without going through HTTP hooks, useful for debugging and reporting
- **One-off migrations** — if Audos-stored data ever needs reshape, direct SQL beats HTTP hook round-trips
- **Schema discovery** — learn the actual shape of Audos data models, useful for integrations

**Worth noting**: Throughline's daemon has its OWN Postgres (`maykapal.public.*`) for all Throughline-specific data (episodes, guests, contacts, communications, sources, podcast_config, assets). The Audos workspace DB is separate and contains Audos-platform data (whatever Audos stores about the workspace). Direct access to `ws_351699` would give us visibility into Audos's side of the relationship, not into Throughline's own daemon DB.

## Documentation to add once the feature works

- Connection string format (host, port, role, password, SSL mode)
- Schema layout (tables available, read vs write permissions)
- Rate limits / connection pool behavior
- Credential rotation policy
- Cross-reference to `AI-HOOK-CAPABILITY-MATRIX.md` since both are workspace-scoped surfaces

## Reference

- Audos workspace ID for Throughline: `workspace-351699` (used in AI hook URLs)
- Audos workspace schema (claimed): `ws_351699`
- AI hook endpoint (working): `https://audos.com/api/hooks/execute/workspace-351699/ai-api`
- Database access endpoint (unknown — to be captured from DevTools)

## Schema discovery (2026-04-16, connection verified)

Connection successful to DigitalOcean-hosted Postgres. Schema `ws_8f1ad824_832f_4af8_b77e_ab931a250625` contains 20 tables with `app_` prefix convention. 22 total rows across the workspace.

### Tables with data

| Table | Rows | Key columns |
|---|---|---|
| `app_outreach_leads` | 11 | name, email, linkedin_url, relevance_score, ai_reason, status, outreach_batch_id |
| `app_speakers` | 3 | name, role, is_recurring, voice_profile_id |
| `app_voice_profiles` | 2 | name, type, sample_count, is_trained, long_form_samples (jsonb) |
| `app_dashboard_activity` | 2 | activity_type, title, description, metadata (jsonb) |
| `app_linked_references` | 2 | url, title, content, content_length, fetched_at |
| `app_guest_prep_podcast_profiles` | 1 | podcast_name, target_audience, style, tone, brand_voice, themes_goals |
| `app_reels` | 1 | title, transcript, video_url, guest_name |

### Empty tables (schema exists, no data)

app_briefing_podcast_profiles, app_briefing_research_sessions, app_briefing_ros_versions, app_generated_captions, app_guest_prep_research_sessions, app_guest_prep_ros_versions, app_podcast_setup_profiles, app_reel_captions, app_studio_content, app_studio_episodes, app_studio_generated_content, app_studio_time_tracking, app_voice_refinements

### Observations

- Audos has its OWN data model that mirrors some of what throughline-daemon stores (podcast profiles, research sessions, voice profiles, reels/captions). The two systems have overlapping schemas.
- `app_outreach_leads` has 11 rows with relevance_score + ai_reason — this is a CRM-like surface that Audos already models. Worth understanding whether the Throughline `contacts` table should sync from or merge with this.
- All tables use `session_id` (text) which ties data to the Audos workspace session. Most also have `user_id` + `org_id` for multi-tenancy.
- Schema uses UUIDs for relational FKs (voice_profile_id, research_session_id, episode_id, etc.) and jsonb for flexible fields (metadata, long_form_samples, learned_patterns).
- Connection credentials stored in Audos Developer panel (Generate Credentials), NOT in this file.

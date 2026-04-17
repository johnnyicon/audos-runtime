# Audos Database Access

Authoritative reference for the Audos workspace Postgres schema — how tables are created, who writes to them, how to integrate from off-platform, and the known gotchas.

**Source:** Consolidated from Otto's `AUDOS-WORKSPACE-DATABASE-ARCHITECTURE` (2026-04-03) plus Throughline-side discovery (2026-04-16) and Otto Q&A session (2026-04-17). Raw Otto artifact preserved at `references/otto-workspace-database-architecture-2026-04-03.md`.

**Related:** [`AI-HOOK-CAPABILITY-MATRIX.md`](../AI-HOOK-CAPABILITY-MATRIX.md) — both are workspace-scoped surfaces and share the same workspace identity model.

**Table ownership analysis:** `15-workspace-db-table-ownership.md` — full classification of all 20 workspace tables, what was dropped, what was kept, and why.

---

## Overview

- **Engine:** Managed PostgreSQL (DigitalOcean-hosted; Audos-operated)
- **Isolation:** Schema-per-workspace multi-tenancy
- **Throughline workspace schema:** `ws_8f1ad824_832f_4af8_b77e_ab931a250625`
- **Workspace ID surface (AI hook URL):** `workspace-351699`

### Critical architectural distinction — workspace schema vs. platform DB

**The workspace schema is entirely app-scaffold.** The Audos platform does not auto-provision tables here. Every table exists because Otto created it during a conversation, or because a platform feature wrote to it when Kane used it.

**Audos platform infrastructure lives in a separate platform DB**, not in the workspace schema. Tables like `funnel_contacts`, `funnel_events`, `ad_campaigns`, `slide_decks`, `boosters`, `session_recordings`, and `payments` are in Audos's own DB. You access them through Otto tools (`query_contacts`, `get_funnel_metrics`, etc.) — they are never directly queryable via the workspace credentials.

**Only one Audos platform feature writes to the workspace schema: Lead Scout → `app_outreach_leads`.** All other platform features (analytics, CRM, ads, payments, carousel, boosters, voiceover, video, image generation) use the platform DB exclusively. Dropping any workspace table other than `app_outreach_leads` cannot break any Audos platform feature.

### Access methods

| Method | Access | Use case |
|---|---|---|
| **Direct SQL** (scoped Postgres role) | Full read/write on workspace schema | Off-platform daemons, reporting, migrations |
| **db-api hook** (HTTP) | Full CRUD + DDL | Apps + external services when direct SQL isn't available |
| **Otto tools** (`db_query`, `db_create_table`, etc.) | Full CRUD + DDL | Agentic workflows driven from chat |
| **Mini-app SDK** (`useWorkspaceDB`) | Session-scoped CRUD | Frontend apps rendered in Audos Space |
| **`execute_sql`** (Otto) | SELECT only | Ad-hoc read queries from chat |

---

## Table lifecycle

Tables are **not auto-provisioned**. They are created explicitly via:

| Method | Who uses it | Example |
|---|---|---|
| Otto `db_create_table` | Agentic chat workflows | "Create a table for voice profiles" |
| db-api hook | External services via HTTP | `POST .../db-api` with `action: "create_table"` |
| Direct SQL | Off-platform daemon | `CREATE TABLE ws_xxx.my_table (...)` |
| `delegate_database_design` | Otto subagent for complex schemas | "Design a database for my podcast studio" |

There is **no centralized schema definition**. The platform tracks tables via a `__table_registry` metadata table (name, display name, description, column docs, created timestamp). **Tables created via direct SQL are not automatically registered.**

**The platform will not overwrite your schema.** Audos does not auto-migrate, drop, or alter tables you own. Otto only creates tables or adds columns when explicitly asked.

---

## Naming & column conventions

### Table naming

| Pattern | Mandatory? | Meaning |
|---|---|---|
| `snake_case` | **Yes** | All tables |
| `app_*` prefix | **No** — see discrepancy note below | Varies by how the table was created |
| `guest_prep_*`, `briefing_*`, `studio_*` | Convention | Groups tables by mini-app |
| `go_*` / `ext_*` | **Recommended for off-platform daemons** | Makes ownership obvious |

> **Discrepancy to verify:** Otto's authoritative doc lists Throughline's workspace tables **without** an `app_*` prefix (e.g. `voice_profiles`, `speakers`, `outreach_leads`). Direct SQL inspection on 2026-04-16 saw them **with** `app_*` prefix (`app_voice_profiles`, `app_speakers`, `app_outreach_leads`) and counted 20 tables rather than 17. Possible explanations: Otto's doc was generated for a different workspace template, or a schema change (prefix rename, extra tables) happened between 2026-04-03 and 2026-04-16. Treat Kane's live observation as ground truth for this workspace; re-run discovery before relying on exact table names.

### Standard columns (auto-added by Otto-created tables)

| Column | Type | Purpose |
|---|---|---|
| `id` | `serial` (PK) | Primary key |
| `created_at` | `timestamp` | Row creation |
| `updated_at` | `timestamp` | Last modification — **see gotcha #2** |
| `session_id` | `text` | User session scoping — **see below** |

### `session_id` scoping

`session_id` ties a row to a visitor session in the Audos Space frontend.

- **Mini-apps** using `useWorkspaceDB('table')` only see rows matching the current session.
- **Shared reads:** `useWorkspaceDB('table', { shared: true })` ignores `session_id`.
- **Otto / db-api / direct SQL writes:** set `session_id = NULL` (or leave unset). These rows are invisible to mini-apps unless `{ shared: true }` is used.

**Off-platform daemon guidance:** set `session_id = NULL` explicitly for anything that should be workspace-wide shared data.

### `user_id` / `org_id`

Not platform-managed. You choose the format (email, UUID, slug). Throughline uses:
- `user_id`: `john@merkhetventures.com`
- `org_id`: `sow-good-to-grow-good`

### ID types

| Column | Type | When |
|---|---|---|
| `id` | `serial` (integer) | Auto-increment PK |
| `related_id` / FK columns | `uuid` | References to external entities |
| `outreach_batch_id` | `text` (UUID format) | Platform-generated batch IDs |
| `session_id` | `text` (UUID format) | Visitor session |
| `user_id`, `org_id` | `text` | Caller-defined |

### JSONB columns

`jsonb` is used liberally for flexible data. No strict schema enforcement — the platform will accept any valid JSON. Examples: `dashboard_activity.metadata`, `voice_profiles.long_form_samples`, `voice_profiles.learned_patterns`.

---

## Data flow — who writes what

After the 2026-04-17 cleanup, the only remaining workspace table is:

| Table | Primary writer | Notes |
|---|---|---|
| `app_outreach_leads` | **Lead Scout (platform feature)** | Writes when Kane asks Otto to scout leads. User-initiated — Audos does not write here for its own purposes. Otto confirmed: if dropped, Lead Scout recreates the table on next use. See deep dive below. |

All other workspace tables from the original 20 were app-scaffold (created by Otto for deprecated Throughline apps) and have been dropped via Atlas migration `20260417000000_cleanup_deprecated_app_tables`.

**No workspace tables are read-only.** Direct SQL has full write. Watch for concurrent writes on `app_outreach_leads.status`/`notes` if Lead Scout is running.

**Direct SQL bypasses platform side-effects** — always set `updated_at = NOW()` explicitly on UPDATEs; don't rely on triggers.

---

## Schema management

### Adding tables (from your daemon)

```sql
CREATE TABLE ws_8f1ad824_832f_4af8_b77e_ab931a250625.go_sync_state (
  id SERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  last_synced_at TIMESTAMP NOT NULL DEFAULT NOW(),
  sync_hash TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

Or via db-api hook (HTTP):

```bash
curl -X POST https://audos.com/api/hooks/execute/workspace-351699/db-api \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{
    "action": "create_table",
    "table": "go_sync_state",
    "columns": [
      { "name": "entity_type", "type": "text", "nullable": false },
      { "name": "entity_id",   "type": "text", "nullable": false },
      { "name": "last_synced_at", "type": "timestamp" },
      { "name": "sync_hash",   "type": "text" }
    ]
  }'
```

### Altering tables

```sql
ALTER TABLE ws_xxx.voice_profiles ADD COLUMN external_id TEXT;
CREATE INDEX idx_vp_external_id ON ws_xxx.voice_profiles(external_id);
```

### Migrations

No platform-provided migration system. Options:
- **Local Atlas workflow** — run local Postgres, generate with Atlas, ask Otto to apply to the Audos DB.
- **Your daemon** — manage migrations with `golang-migrate` / Atlas directly against the workspace schema.

---

## Hook → database interaction

Server functions receive an injected `db` object:

```javascript
export default async function handler(request, { db, platform, respond }) {
  const rows = await db.query('voice_profiles', {
    filters: [{ column: 'type', operator: 'eq', value: 'host' }],
    limit: 10,
  });

  await db.insert('dashboard_activity', [{
    activity_type: 'api_test',
    title: 'Test',
    metadata: { source: 'hook' },
  }]);

  await db.update('speakers', {
    filters: [{ column: 'id', operator: 'eq', value: 1 }],
    data: { notes: 'Updated from hook' },
  });

  await db.delete('linked_references', {
    filters: [{ column: 'id', operator: 'eq', value: 99 }],
  });

  const tables = await db.listTables();
  respond(200, { rows, tables });
}
```

**Note:** The `ai-api` hook **does not touch the database.** It's a pure OpenAI proxy. Add `db.*` calls inside the hook if you want to log AI interactions.

---

## `outreach_leads` deep dive — Audos agentic CRM

`outreach_leads` is the data store for Audos's **Lead Scout** agentic CRM feature.

```
1. User asks Otto: "Find podcast producers for outreach"
2. Otto → start_lead_scout tool
3. Lead Scout agent:
     - Searches web / LinkedIn
     - AI scores each lead (relevance_score, ai_reason)
     - Inserts rows
4. User reviews leads in the Outreach window
5. Status funnel: new → drafted → contacted → responded → scheduled
                                            └→ not_interested
```

### Status writers

| Transition | Writer |
|---|---|
| `new` → `drafted` | Otto's `draft_outreach_email` tool (draft stored in `notes`) |
| `drafted` → `contacted` | Platform (when email sends) |
| `contacted` → `responded` / `scheduled` / `not_interested` | User or Otto |

### Key columns

| Column | Populated by | Purpose |
|---|---|---|
| `relevance_score` | Lead Scout AI | 0-100 |
| `ai_reason` | Lead Scout AI | Why this lead fits |
| `outreach_batch_id` | Lead Scout | Groups leads from one search job |
| `notes` | Otto | Draft email content |
| `status` | Platform / Otto | Funnel state |
| `session_id` | `NULL` | Agent-generated, not session-scoped |

You can insert leads directly via SQL — just be aware that the Lead Scout agent may concurrently update `status` / `notes` on rows you care about.

### Overlap with Throughline `contacts`

Throughline has its own first-class `contacts` table (replacing the legacy `guests` table, April 2026). `outreach_leads` is a separate Audos-side CRM surface. Consider: sync from `outreach_leads` → Throughline `contacts`, or treat them as independent systems. No automatic linkage today.

---

## Off-platform integration patterns

### Pattern 1 — Direct SQL (recommended)

```go
package main

import (
    "database/sql"
    _ "github.com/lib/pq"
)

const audosSchema = "ws_8f1ad824_832f_4af8_b77e_ab931a250625"

func main() {
    db, _ := sql.Open("postgres", "postgres://user:pass@host/db?sslmode=require")

    // Read
    rows, _ := db.Query(`SELECT id, name, type FROM ` + audosSchema + `.voice_profiles`)

    // Write (shared — session_id NULL)
    db.Exec(`INSERT INTO `+audosSchema+`.dashboard_activity
        (activity_type, title, metadata, session_id, updated_at)
        VALUES ($1, $2, $3::jsonb, NULL, NOW())`,
        "go_sync", "Sync completed", `{"source":"go_daemon"}`)
}
```

### Pattern 2 — HTTP via db-api hook

When direct SQL isn't available (e.g. serverless):

```go
payload := map[string]any{
    "action": "query",
    "table":  "voice_profiles",
    "limit":  10,
}
req, _ := http.NewRequest("POST",
    "https://audos.com/api/hooks/execute/workspace-351699/db-api",
    bytes.NewBuffer(jsonPayload))
req.Header.Set("x-api-key", "your-api-key")
req.Header.Set("Content-Type", "application/json")
```

### Pattern 3 — Sync table for loose coupling

```sql
CREATE TABLE ws_xxx.go_sync_state (
  id SERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL,       -- 'voice_profile', 'speaker', ...
  entity_id   INTEGER NOT NULL,
  last_synced_at TIMESTAMP NOT NULL,
  sync_hash   TEXT,                -- MD5 of row to detect drift
  sync_direction TEXT DEFAULT 'both'
);
```

### Pattern 4 — Webhook callbacks for near-real-time

A hook pings your daemon on write:

```javascript
// notify-daemon hook
export default async function handler(request, { respond }) {
  const { eventType, table, rowId } = request.body;
  await fetch('https://your-daemon.example.com/webhook', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ eventType, table, rowId }),
  });
  respond(200, { ok: true });
}
```

### Polling fallback

```sql
SELECT * FROM ws_xxx.voice_profiles WHERE updated_at > $1;
```

Only works if every writer (including direct SQL) sets `updated_at` on UPDATE — see gotcha #2.

---

## Complete table reference

### Current state — post-cleanup (2026-04-17)

The workspace schema was cleaned up via Atlas migration `20260417000000_cleanup_deprecated_app_tables`. 19 app-scaffold tables were dropped. One table remains:

| Table | Rows | Purpose | Key columns |
|---|---|---|---|
| `app_outreach_leads` | 11 | Lead Scout CRM — AI-scouted Throughline sales prospects | `name`, `company`, `title`, `relevance_score`, `ai_reason`, `status`, `notes` (draft email), `outreach_batch_id` |

**All other tables were dropped.** See `15-workspace-db-table-ownership.md` for the full classification rationale and Otto confirmations.

### Historical — what was dropped (2026-04-17)

These 19 tables were confirmed app-scaffold (created by Otto for deprecated Throughline apps) with no active Audos platform feature dependency:

| Group | Tables dropped |
|---|---|
| Briefing app | `app_briefing_podcast_profiles`, `app_briefing_research_sessions`, `app_briefing_ros_versions` |
| Guest Prep app | `app_guest_prep_podcast_profiles`, `app_guest_prep_research_sessions`, `app_guest_prep_ros_versions` |
| Studio app | `app_studio_episodes`, `app_studio_content`, `app_studio_generated_content`, `app_studio_time_tracking` |
| Podcast Setup wizard | `app_podcast_setup_profiles` |
| Voice/speaker features | `app_speakers`, `app_voice_profiles`, `app_voice_refinements` |
| Reels/captions | `app_reels`, `app_reel_captions`, `app_generated_captions` |
| Misc app-scaffold | `app_dashboard_activity`, `app_linked_references` |

---

## Gotchas & limitations

### 1. `session_id` scoping
Direct SQL inserts with `session_id = NULL` are invisible to mini-apps unless they opt in with `useWorkspaceDB('table', { shared: true })`.

### 2. `updated_at` is not auto-maintained on direct SQL
UPDATE triggers may not exist. Always set `updated_at` explicitly:
```sql
UPDATE ws_xxx.voice_profiles SET name = $1, updated_at = NOW() WHERE id = $2;
```
Polling sync strategies depend on this being consistent across all writers.

### 3. Foreign keys not consistently enforced
FKs are documented but not always present at the DB level. Either validate in application code or add constraints yourself:
```sql
ALTER TABLE ws_xxx.speakers
  ADD CONSTRAINT fk_speakers_voice_profile
  FOREIGN KEY (voice_profile_id) REFERENCES ws_xxx.voice_profiles(id);
```

### 4. No change data capture
No built-in CDC / event stream. Options: poll on `updated_at`, build webhook hooks, or use Postgres `LISTEN/NOTIFY` if your role has access.

### 5. Concurrent writers
Last-write-wins if your daemon and Otto/mini-apps both write the same rows. Mitigations: distinct tables/rows per system, a `last_modified_by` column, or version-number optimistic locking.

### 6. Direct SQL bypasses platform side-effects
Validation, trigger-driven timestamp bumps, audit logging — if the platform adds any, direct SQL skips them. Replicate in your daemon.

---

## Key takeaways for the Throughline daemon

1. **The workspace schema is app-scaffold, not platform infrastructure.** Only `app_outreach_leads` is written by an Audos platform feature (Lead Scout). Everything else is yours to create and manage.
2. **Audos platform features use a separate platform DB** — analytics, CRM, ads, payments, carousel, boosters, voiceover, image/video generation all store data there. They are not accessible via workspace credentials; use Otto tools to read/write them.
3. **Direct SQL is fully supported** — read and write freely within the workspace schema.
4. **Prefix new daemon-owned tables** with `throughline_` (or `ext_`) to keep ownership visible. Managed via Atlas `audos-workspace` env in `throughline-daemon/atlas.hcl`.
5. **Set `session_id = NULL`** on daemon-written rows intended as shared workspace data.
6. **Always set `updated_at = NOW()`** on UPDATEs — don't rely on triggers.
7. **Avoid concurrent writes** to `app_outreach_leads.status`/`notes` if Lead Scout is also running.
8. **Throughline's own data lives in the daemon's Postgres** — episodes, contacts, communications, sources, podcast_config, assets. The Audos workspace schema holds only Lead Scout data (`app_outreach_leads`) and any future `throughline_*` tables explicitly created by the daemon.

---

## Appendix — credential generation discovery (2026-04-16)

The Audos Developer panel exposes a **Database Access** card that claims to generate scoped PostgreSQL credentials for local-development use.

**Observed:** clicking "Generate Credentials" returns a toast `Error — Workspace not found`. No credentials generated, no UI state change.

**Diagnosis in flight:**

- The real API path is unknown. Blind probes of likely patterns returned generic `API route not found` (distinct from the UI's `Workspace not found`), meaning the endpoint exists server-side but workspace `351699` doesn't resolve in whatever lookup it uses.
- Probed and ruled out: `/api/workspaces/:id/database-credentials`, `/api/workspace/:id/database-credentials`, `/api/workspaces/:id/credentials`, `/api/database/credentials`, `/api/developer/database-credentials`, `/api/dev/database`, `/api/credentials/generate`, `/api/hooks/execute/workspace-:id/database`.

**Hypotheses:**
1. Provisioning gap — back-end role not provisioned for `ws_351699`.
2. ID mismatch — endpoint wants a UUID, numeric `351699` doesn't resolve.
3. Session/auth — UI session's workspace claim differs from displayed workspace.
4. Feature flag — UI-enabled, back-end-disabled.

**Next step:** capture the failing request from the browser DevTools Network tab (URL + body + response) to pinpoint endpoint and exact server error.

**Note:** The DigitalOcean-hosted Postgres was successfully connected to on 2026-04-16 using credentials stored separately (not via the Developer panel). That's how the live schema discovery was done.

---

## Documentation to add once the Developer-panel generator works

- Connection string format (host, port, role, password, SSL mode)
- Exact permission grants (read vs write per schema)
- Rate limits / connection pool behavior
- Credential rotation policy

# Throughline Database Migrations

> **Contract Version:** 1.0.0
> **Last Updated:** July 2025

This directory contains database schema migrations for the Throughline application. Migrations are developed locally against a PostgreSQL instance and then applied to the Audos platform via Otto.

---

## Quick Start

```bash
# 1. Start local PostgreSQL
docker-compose up -d

# 2. Apply existing migrations locally
atlas migrate apply --env local

# 3. Make schema changes, then create a new migration
atlas migrate diff my_new_feature --env local

# 4. Test locally, then commit
git add database/
git commit -m "Add migration: my_new_feature"
git push

# 5. Tell Otto to apply
# "Hey Otto, apply database migrations from my repo"
```

---

## Directory Structure

```
database/
├── README.md                    # This file (contract/documentation)
├── atlas.hcl                    # Atlas configuration
├── schema.sql                   # Current schema (source of truth)
├── docker-compose.yml           # Local PostgreSQL setup
├── _migrations_index.json       # Migration tracking (managed by Otto)
└── migrations/                  # Migration files
    ├── 20250701000000_initial_schema.sql
    └── ...
```

---

## The Contract: What Otto Expects

### Migration File Location

All migrations must be in `database/migrations/` directory.

### Migration File Naming

```
YYYYMMDDHHMMSS_descriptive_name.sql
```

Examples:
- `20250701120000_initial_schema.sql`
- `20250701130000_add_voice_profiles.sql`
- `20250701140000_add_org_id_columns.sql`

### Migration File Format (SQL)

```sql
-- migration: 20250701140000_add_org_id_columns
-- description: Add org_id to all user-scoped tables
-- author: your_name

-- Your DDL statements here
ALTER TABLE voice_profiles ADD COLUMN org_id TEXT;
CREATE INDEX idx_voice_profiles_org_id ON voice_profiles(org_id);

-- rollback:
-- DROP INDEX idx_voice_profiles_org_id;
-- ALTER TABLE voice_profiles DROP COLUMN org_id;
```

**Required metadata comments:**
- `-- migration:` — The migration version/ID (must match filename)
- `-- description:` — What this migration does

**Optional metadata:**
- `-- author:` — Who created this migration
- `-- rollback:` — SQL to undo this migration (for documentation)

### Alternative: JSON Format

For explicit control, you can use JSON instead of SQL:

```json
{
  "version": "20250701140000",
  "name": "add_org_id_columns",
  "description": "Add org_id to all user-scoped tables",
  "operations": [
    {
      "type": "add_column",
      "table": "voice_profiles",
      "column": { "name": "org_id", "type": "text", "nullable": true }
    }
  ]
}
```

Save as `20250701140000_add_org_id_columns.json` in `migrations/`.

---

## Supported Operations Checklist

### ✅ Fully Supported

| Operation | SQL Syntax | Notes |
|-----------|------------|-------|
| Create Table | `CREATE TABLE name (...)` | `id` and `created_at` auto-added by platform |
| Add Column | `ALTER TABLE ADD COLUMN` | All standard types supported |
| Drop Column | `ALTER TABLE DROP COLUMN` | Requires confirmation from user |
| Rename Column | N/A | Use JSON format: `{ "type": "rename_column" }` |
| Add Index | `CREATE INDEX` | Single and composite indexes |
| Add Unique Index | `CREATE UNIQUE INDEX` | Enforces uniqueness |
| Drop Table | `DROP TABLE` | Requires confirmation from user |
| Truncate Table | `TRUNCATE TABLE` | Requires confirmation from user |
| Add Foreign Key | `REFERENCES table(col)` | At table creation time only |

### Supported Data Types

| SQL Type | Platform Type | Notes |
|----------|---------------|-------|
| `TEXT`, `VARCHAR`, `CHAR` | `text` | Variable length strings |
| `INT`, `INTEGER` | `integer` | 32-bit signed |
| `BIGINT` | `bigint` | 64-bit signed |
| `DECIMAL`, `NUMERIC` | `decimal` | Exact numeric |
| `BOOLEAN`, `BOOL` | `boolean` | true/false |
| `TIMESTAMP`, `TIMESTAMPTZ` | `timestamp` | Date and time |
| `DATE` | `date` | Date only |
| `JSON`, `JSONB` | `json` | JSON data |
| `UUID` | `uuid` | Universally unique ID |

### Supported Constraints

| Constraint | Supported | Notes |
|------------|-----------|-------|
| `NOT NULL` | ✅ Yes | `nullable: false` |
| `UNIQUE` | ✅ Yes | `unique: true` |
| `DEFAULT` | ✅ Yes | `defaultValue: "expression"` |
| `PRIMARY KEY` | ✅ Auto | `id` column auto-created |
| `FOREIGN KEY` | ✅ Yes | At table creation only |
| `CHECK` | ❌ No | Not supported |

---

## ❌ Unsupported Operations & Workarounds

| Operation | Status | Workaround |
|-----------|--------|------------|
| **ALTER COLUMN TYPE** | ❌ Not supported | Create new column → migrate data → drop old |
| **ALTER COLUMN SET/DROP NOT NULL** | ❌ Not supported | Recreate column or handle in app |
| **ADD FOREIGN KEY to existing table** | ❌ Not supported | Enforce in app code or recreate table |
| **DROP INDEX** | ❌ Not exposed | Indexes remain (usually harmless) |
| **Raw INSERT/UPDATE/DELETE** | ❌ Not allowed | Use server functions |
| **Custom SQL functions** | ❌ Not exposed | Implement in server functions |
| **Triggers** | ❌ Not exposed | Use server functions + webhooks |
| **Views** | ❌ Not exposed | Query in application code |

### Example Workaround: Change Column Type

To change `count` from TEXT to INTEGER:

**Migration 1: Add new column**
```sql
-- migration: 20250701150000_add_count_integer
ALTER TABLE my_table ADD COLUMN count_new INTEGER;
```

**Server function: Migrate data**
```javascript
// hooks/migrate-count.js
const rows = await db.query('SELECT id, count FROM my_table WHERE count IS NOT NULL');
for (const row of rows) {
  await db.update('my_table',
    [{ column: 'id', operator: 'eq', value: row.id }],
    { count_new: parseInt(row.count, 10) || 0 }
  );
}
```

**Migration 2: Drop old column (after data migrated)**
```sql
-- migration: 20250701160000_drop_old_count
ALTER TABLE my_table DROP COLUMN count;
-- Then rename count_new to count in app code
```

---

## Migration Tracking

The `_migrations_index.json` file tracks which migrations have been applied to Audos.

**DO NOT EDIT THIS FILE MANUALLY** — Otto manages it.

```json
{
  "schemaVersion": "1.0.0",
  "workspaceId": "8f1ad824-832f-4af8-b77e-ab931a250625",
  "applied": [
    {
      "version": "20250701000000",
      "name": "initial_schema",
      "appliedAt": "2025-07-01T00:00:00Z",
      "appliedBy": "otto"
    }
  ],
  "lastApplied": "2025-07-01T00:00:00Z"
}
```

---

## Local Development

### Prerequisites

- Docker Desktop
- Atlas CLI: `brew install ariga/tap/atlas`

### Start Local Database

```bash
cd database
docker-compose up -d

# Verify it's running
docker-compose ps

# Connect via psql
docker exec -it throughline_postgres psql -U dev -d throughline_dev
```

### Apply Migrations Locally

```bash
atlas migrate apply --env local
```

### Create New Migration

```bash
# After modifying schema.sql, generate migration
atlas migrate diff my_feature_name --env local

# Or create manually
touch migrations/$(date +%Y%m%d%H%M%S)_my_feature.sql
```

### Reset Local Database

```bash
docker-compose down -v
docker-compose up -d
atlas migrate apply --env local
```

---

## Workflow Summary

```
┌──────────────────────────────────────────────────────────────┐
│  LOCAL                                                        │
│  1. docker-compose up -d                                     │
│  2. Edit schema.sql or create migration                      │
│  3. atlas migrate apply --env local                          │
│  4. Test your app against local DB                           │
└──────────────────────────────────────────────────────────────┘
                           │
                           │ git push
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  AUDOS (via Otto)                                            │
│  1. "Apply database migrations"                              │
│  2. Otto reads migrations/                                   │
│  3. Otto applies via db_create_table, db_alter_table, etc.  │
│  4. Otto updates _migrations_index.json                      │
└──────────────────────────────────────────────────────────────┘
```

---

## Asking Otto for Help

- **"Apply database migrations"** — Apply pending migrations from repo
- **"What migrations are pending?"** — List unapplied migrations
- **"Describe the voice_profiles table"** — Show current schema
- **"List all database tables"** — Show all tables in workspace

---

## Full Documentation

For complete details, see:
- `docs/AUDOS-DATABASE-MIGRATIONS-SDK.md` — Full SDK documentation

---

*Last synced with Audos schema: July 2025*

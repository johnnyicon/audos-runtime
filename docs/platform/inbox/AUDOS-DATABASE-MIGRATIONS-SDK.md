# Audos Platform: Database Migration SDK

> **Version:** 1.0.0
> **Last Updated:** July 2025
> **Author:** Otto (Audos AI Assistant)
> **Workspace:** Throughline (8f1ad824-832f-4af8-b77e-ab931a250625)

---

## Table of Contents

1. [Overview](#overview)
2. [Platform Database Architecture](#platform-database-architecture)
3. [The Problem: Dev vs Production Data](#the-problem-dev-vs-production-data)
4. [Solution: Local Development + Migration Workflow](#solution-local-development--migration-workflow)
5. [Local Development Setup](#local-development-setup)
6. [Migration File Formats](#migration-file-formats)
7. [How Otto Applies Migrations](#how-otto-applies-migrations)
8. [Supported Operations Checklist](#supported-operations-checklist)
9. [Unsupported Operations & Workarounds](#unsupported-operations--workarounds)
10. [Complete Workflow Example](#complete-workflow-example)
11. [Directory Structure Reference](#directory-structure-reference)
12. [Atlas Configuration](#atlas-configuration)
13. [Docker Setup](#docker-setup)
14. [Migration Tracking](#migration-tracking)
15. [Best Practices](#best-practices)
16. [Troubleshooting](#troubleshooting)
17. [Appendix: Current Schema](#appendix-current-schema)

---

## Overview

This document defines the contract between your local development environment and the Audos platform's hosted PostgreSQL database. It enables you to:

- **Develop locally** with your own PostgreSQL instance
- **Use Atlas (or any migration tool)** to manage schema changes
- **Push migrations to GitHub** where Otto can read and apply them
- **Keep development data separate** from production data

### Key Principle

```
┌─────────────────────────────────────────────────────────────────────────┐
│  YOUR LOCAL ENVIRONMENT          │  AUDOS PLATFORM                     │
│                                   │                                      │
│  - Full PostgreSQL access         │  - API-only access                   │
│  - Direct SQL execution           │  - Tool-mediated operations          │
│  - Test/dev data                  │  - Production data                   │
│  - Fast iteration                 │  - Deployed application              │
│                                   │                                      │
│  Schema changes committed as      │  Otto reads migrations and           │
│  migration files ─────────────────│──> applies via platform tools        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Platform Database Architecture

### Database Technology

| Aspect | Detail |
|--------|--------|
| **Database Engine** | PostgreSQL |
| **Hosting** | Managed (Google Cloud SQL or similar) |
| **Multi-tenancy** | Schema-per-workspace isolation |
| **Your Schema** | `ws_8f1ad824_832f_4af8_b77e_ab931a250625` |
| **Access Methods** | Platform APIs only (no direct connection) |

### Access Methods Available

1. **Platform APIs** — REST endpoints at `/api/workspace-db/...`
2. **Server Functions** — `db.query()`, `db.insert()`, `db.update()`, `db.delete()` in hooks
3. **Otto Tools** — `db_create_table`, `db_alter_table`, `db_query`, etc.
4. **Read-Only SQL** — `execute_sql` and `workspace_execute_sql` (SELECT only)

### What's NOT Available

- ❌ Direct PostgreSQL connection string
- ❌ Raw DDL execution (CREATE TABLE, ALTER TABLE via SQL)
- ❌ Raw DML execution (INSERT, UPDATE, DELETE via SQL)
- ❌ Database superuser access
- ❌ Schema-level operations outside your workspace

---

## The Problem: Dev vs Production Data

### Why This Matters

If you develop locally but use the Audos-hosted database:

1. **Test data pollutes production** — Your `test@example.com` contacts, dummy records, and debug data end up in your live database
2. **No isolation** — You can't easily reset or clean up development data
3. **Slow iteration** — Every schema change requires API calls, which is slower than local DDL
4. **Risk of accidents** — A wrong `DELETE` or `DROP` affects real data

### The Solution

**Use a local PostgreSQL database for development, then apply schema changes to Audos via migrations.**

```
Development Data ──────> Local PostgreSQL (disposable)
Schema Changes ─────────> Migration Files ──────> Audos Platform (via Otto)
Production Data ────────> Audos PostgreSQL (protected)
```

---

## Solution: Local Development + Migration Workflow

### High-Level Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 1: LOCAL DEVELOPMENT                                              │
│                                                                          │
│  1. Run local Postgres via Docker                                       │
│  2. Use Atlas to manage schema migrations                               │
│  3. Develop and test with local data                                    │
│  4. Iterate quickly with full SQL access                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ git add && git commit && git push
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 2: COMMIT MIGRATIONS                                              │
│                                                                          │
│  Migration files are committed to:                                      │
│    database/migrations/YYYYMMDDHHMMSS_description.sql                   │
│                                                                          │
│  Tracking file updated:                                                 │
│    database/_migrations_index.json                                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Sync to Audos via GitHub
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 3: DEPLOYMENT (via Otto)                                          │
│                                                                          │
│  You: "Apply database migrations from my repo"                          │
│                                                                          │
│  Otto:                                                                  │
│    1. Reads database/_migrations_index.json                             │
│    2. Identifies pending migrations                                     │
│    3. Reads each migration file                                         │
│    4. Translates SQL to platform tool calls                             │
│    5. Executes via db_create_table, db_alter_table, etc.               │
│    6. Updates _migrations_index.json with applied status               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  STEP 4: VERIFICATION                                                   │
│                                                                          │
│  Otto confirms what was applied                                         │
│  You can verify via db_describe_table or db_query                       │
│  Production data remains untouched (only schema changed)                │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Local Development Setup

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Docker** | Run local PostgreSQL | [docker.com](https://docker.com) |
| **Atlas** | Schema migration management | `brew install ariga/tap/atlas` or [atlasgo.io](https://atlasgo.io) |
| **Go** | Atlas is written in Go (optional for custom tooling) | [go.dev](https://go.dev) |
| **psql** | PostgreSQL CLI (optional) | Comes with Docker image |

### Quick Start

```bash
# 1. Navigate to your project
cd throughline

# 2. Start local PostgreSQL
docker-compose up -d

# 3. Initialize Atlas (if not already done)
atlas migrate init

# 4. Create your first migration
atlas migrate diff initial_schema \
  --to "file://database/schema.sql" \
  --dev-url "docker://postgres/15"

# 5. Apply locally
atlas migrate apply \
  --url "postgres://dev:dev@localhost:5432/throughline_dev?sslmode=disable"

# 6. Develop, iterate, test...

# 7. When ready, commit and push
git add database/
git commit -m "Add new migration: add_org_id_columns"
git push

# 8. Tell Otto to apply
# "Hey Otto, apply database migrations from my repo"
```

---

## Migration File Formats

Otto can parse two migration file formats. Choose the one that fits your workflow.

### Format A: SQL with Metadata Comments (Recommended)

This format works with Atlas and most SQL migration tools.

```sql
-- migration: 20250701140000_add_org_id_columns
-- description: Add org_id to all user-scoped tables for multi-tenancy
-- author: john
-- created: 2025-07-01T14:00:00Z

-- Up Migration
ALTER TABLE voice_profiles ADD COLUMN org_id TEXT;
ALTER TABLE podcast_profiles ADD COLUMN org_id TEXT;
ALTER TABLE speakers ADD COLUMN org_id TEXT;

-- Index for performance
CREATE INDEX idx_voice_profiles_org_id ON voice_profiles(org_id);
CREATE INDEX idx_podcast_profiles_org_id ON podcast_profiles(org_id);
CREATE INDEX idx_speakers_org_id ON speakers(org_id);

-- rollback:
-- DROP INDEX idx_speakers_org_id;
-- DROP INDEX idx_podcast_profiles_org_id;
-- DROP INDEX idx_voice_profiles_org_id;
-- ALTER TABLE speakers DROP COLUMN org_id;
-- ALTER TABLE podcast_profiles DROP COLUMN org_id;
-- ALTER TABLE voice_profiles DROP COLUMN org_id;
```

#### Parsing Rules

Otto extracts:
- **Version** from `-- migration:` comment
- **Description** from `-- description:` comment
- **Operations** from SQL statements (supports CREATE TABLE, ALTER TABLE, CREATE INDEX)
- **Rollback** from `-- rollback:` section (for documentation/manual use)

### Format B: JSON Migration Format (Explicit)

For maximum control and clarity, use JSON format.

```json
{
  "version": "20250701140000",
  "name": "add_org_id_columns",
  "description": "Add org_id to all user-scoped tables for multi-tenancy",
  "author": "john",
  "created": "2025-07-01T14:00:00Z",
  "operations": [
    {
      "type": "add_column",
      "table": "voice_profiles",
      "column": {
        "name": "org_id",
        "type": "text",
        "nullable": true,
        "description": "Organization ID for multi-tenancy"
      }
    },
    {
      "type": "add_column",
      "table": "podcast_profiles",
      "column": {
        "name": "org_id",
        "type": "text",
        "nullable": true
      }
    },
    {
      "type": "add_column",
      "table": "speakers",
      "column": {
        "name": "org_id",
        "type": "text",
        "nullable": true
      }
    },
    {
      "type": "add_index",
      "table": "voice_profiles",
      "columns": ["org_id"],
      "unique": false
    },
    {
      "type": "add_index",
      "table": "podcast_profiles",
      "columns": ["org_id"],
      "unique": false
    },
    {
      "type": "add_index",
      "table": "speakers",
      "columns": ["org_id"],
      "unique": false
    }
  ],
  "rollback": [
    { "type": "drop_index", "table": "speakers", "columns": ["org_id"] },
    { "type": "drop_index", "table": "podcast_profiles", "columns": ["org_id"] },
    { "type": "drop_index", "table": "voice_profiles", "columns": ["org_id"] },
    { "type": "drop_column", "table": "speakers", "column": "org_id" },
    { "type": "drop_column", "table": "podcast_profiles", "column": "org_id" },
    { "type": "drop_column", "table": "voice_profiles", "column": "org_id" }
  ]
}
```

#### JSON Operation Types

| Type | Parameters | Maps To |
|------|------------|---------|
| `create_table` | `table`, `columns`, `foreignKeys?` | `db_create_table` |
| `add_column` | `table`, `column` | `db_alter_table.addColumns` |
| `drop_column` | `table`, `column` | `db_alter_table.dropColumns` |
| `rename_column` | `table`, `from`, `to` | `db_alter_table.renameColumns` |
| `add_index` | `table`, `columns`, `unique?` | `db_alter_table.addIndexes` |
| `drop_table` | `table` | `db_drop_table` |

---

## How Otto Applies Migrations

### Step-by-Step Process

#### 1. Read Migration Index

Otto first reads `database/_migrations_index.json`:

```json
{
  "schemaVersion": "1.0.0",
  "applied": [
    {
      "version": "20250701120000",
      "name": "initial_schema",
      "appliedAt": "2025-07-01T12:00:00Z",
      "appliedBy": "otto"
    },
    {
      "version": "20250701130000",
      "name": "add_voice_profiles",
      "appliedAt": "2025-07-01T13:00:00Z",
      "appliedBy": "otto"
    }
  ],
  "lastApplied": "2025-07-01T13:00:00Z"
}
```

#### 2. Scan for Pending Migrations

Otto lists files in `database/migrations/` and identifies any not in `applied[]`.

#### 3. Read and Parse Each Migration

For SQL format:
```
Parse SQL → Extract statements → Map to platform operations
```

For JSON format:
```
Parse JSON → Read operations[] → Map to platform tool calls
```

#### 4. Execute via Platform Tools

SQL Statement → Platform Tool Translation:

```sql
-- Your migration says:
ALTER TABLE voice_profiles ADD COLUMN org_id TEXT;

-- Otto executes:
db_alter_table({
  table: "voice_profiles",
  changes: {
    addColumns: [{ name: "org_id", type: "text", nullable: true }]
  }
});
```

```sql
-- Your migration says:
CREATE TABLE new_feature (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Otto executes:
db_create_table({
  name: "new_feature",
  columns: [
    { name: "name", type: "text", nullable: false }
  ]
  // Note: id and created_at are auto-added by platform
});
```

#### 5. Update Migration Index

After successful application:

```json
{
  "applied": [
    // ... previous entries ...
    {
      "version": "20250701140000",
      "name": "add_org_id_columns",
      "appliedAt": "2025-07-01T14:30:00Z",
      "appliedBy": "otto"
    }
  ],
  "lastApplied": "2025-07-01T14:30:00Z"
}
```

---

## Supported Operations Checklist

### ✅ Fully Supported

| Operation | SQL Syntax | Platform Tool | Notes |
|-----------|------------|---------------|-------|
| **Create Table** | `CREATE TABLE name (...)` | `db_create_table` | `id` and `created_at` auto-added |
| **Add Column** | `ALTER TABLE ADD COLUMN` | `db_alter_table.addColumns` | All standard types supported |
| **Drop Column** | `ALTER TABLE DROP COLUMN` | `db_alter_table.dropColumns` | Requires confirmation |
| **Rename Column** | N/A (not standard SQL) | `db_alter_table.renameColumns` | Use JSON format |
| **Add Index** | `CREATE INDEX` | `db_alter_table.addIndexes` | Single and composite |
| **Add Unique Index** | `CREATE UNIQUE INDEX` | `db_alter_table.addIndexes` | Set `unique: true` |
| **Drop Table** | `DROP TABLE` | `db_drop_table` | Requires confirmation |
| **Truncate Table** | `TRUNCATE TABLE` | `db_truncate_table` | Requires confirmation |
| **Add Foreign Key** | `REFERENCES table(col)` | `db_create_table.foreignKeys` | At creation time only |

### Supported Data Types

| Type | PostgreSQL | Platform Type | Notes |
|------|------------|---------------|-------|
| `TEXT` | `text`, `varchar`, `char` | `text` | Variable length strings |
| `INTEGER` | `int`, `integer`, `int4` | `integer` | 32-bit signed integer |
| `BIGINT` | `bigint`, `int8` | `bigint` | 64-bit signed integer |
| `DECIMAL` | `decimal`, `numeric` | `decimal` | Exact numeric |
| `BOOLEAN` | `boolean`, `bool` | `boolean` | true/false |
| `TIMESTAMP` | `timestamp`, `timestamptz` | `timestamp` | Date and time |
| `DATE` | `date` | `date` | Date only |
| `JSON` | `json`, `jsonb` | `json` | JSON data |
| `UUID` | `uuid` | `uuid` | Universally unique identifier |

### Supported Column Constraints

| Constraint | Supported | Notes |
|------------|-----------|-------|
| `NOT NULL` | ✅ Yes | `nullable: false` |
| `UNIQUE` | ✅ Yes | `unique: true` |
| `DEFAULT` | ✅ Yes | `defaultValue: "expression"` |
| `PRIMARY KEY` | ✅ Auto | `id` column auto-created |
| `REFERENCES` | ✅ Yes | Via `foreignKeys` at table creation |
| `CHECK` | ❌ No | Not supported by platform |

---

## Unsupported Operations & Workarounds

### ❌ Not Supported

| Operation | Why | Workaround |
|-----------|-----|------------|
| **ALTER COLUMN TYPE** | Platform limitation | Create new column → migrate data → drop old column |
| **ALTER COLUMN SET/DROP NOT NULL** | Platform limitation | Recreate column or handle in app logic |
| **ADD FOREIGN KEY to existing table** | Only at creation | Enforce in application code or recreate table |
| **DROP INDEX** | Not exposed | Indexes remain (usually harmless) |
| **Raw INSERT/UPDATE/DELETE** | Security | Use server functions or app code |
| **Custom SQL functions** | Not exposed | Implement in server functions |
| **Triggers** | Not exposed | Use server functions with webhooks |
| **Views** | Not exposed | Query in application code |
| **Sequences** | Hidden | Use `uuid` type or let platform auto-generate |

### Workaround: Changing Column Type

If you need to change a column from `TEXT` to `INTEGER`:

```json
{
  "version": "20250701150000",
  "name": "change_count_to_integer",
  "description": "Change count column from TEXT to INTEGER",
  "operations": [
    {
      "type": "add_column",
      "table": "my_table",
      "column": { "name": "count_new", "type": "integer", "nullable": true }
    }
  ],
  "manual_steps": [
    "Run data migration via server function to copy count → count_new",
    "Update application code to use count_new",
    "Drop old column in next migration"
  ],
  "followup_migration": "20250701160000_drop_old_count_column"
}
```

Then create a server function to migrate data:

```javascript
// hooks/migrate-count-column.js
const rows = await db.query('SELECT id, count FROM my_table WHERE count IS NOT NULL');
for (const row of rows) {
  const intValue = parseInt(row.count, 10) || 0;
  await db.update('my_table',
    [{ column: 'id', operator: 'eq', value: row.id }],
    { count_new: intValue }
  );
}
return { migrated: rows.length };
```

---

## Complete Workflow Example

### Scenario: Adding Organization Multi-Tenancy

You want to add `org_id` to several tables for multi-tenancy support.

#### Step 1: Create Migration Locally

```bash
# Create migration file
cat > database/migrations/20250701140000_add_org_id_columns.sql << 'EOF'
-- migration: 20250701140000_add_org_id_columns
-- description: Add org_id to all user-scoped tables for multi-tenancy
-- author: john

ALTER TABLE voice_profiles ADD COLUMN org_id TEXT;
ALTER TABLE podcast_profiles ADD COLUMN org_id TEXT;
ALTER TABLE speakers ADD COLUMN org_id TEXT;
ALTER TABLE reels ADD COLUMN org_id TEXT;
ALTER TABLE studio_episodes ADD COLUMN org_id TEXT;

CREATE INDEX idx_voice_profiles_org_id ON voice_profiles(org_id);
CREATE INDEX idx_speakers_org_id ON speakers(org_id);

-- rollback:
-- DROP INDEX idx_speakers_org_id;
-- DROP INDEX idx_voice_profiles_org_id;
-- ALTER TABLE studio_episodes DROP COLUMN org_id;
-- ALTER TABLE reels DROP COLUMN org_id;
-- ALTER TABLE speakers DROP COLUMN org_id;
-- ALTER TABLE podcast_profiles DROP COLUMN org_id;
-- ALTER TABLE voice_profiles DROP COLUMN org_id;
EOF
```

#### Step 2: Test Locally

```bash
# Apply to local database
atlas migrate apply \
  --url "postgres://dev:dev@localhost:5432/throughline_dev?sslmode=disable"

# Verify
psql -U dev -d throughline_dev -c "\d voice_profiles"
```

#### Step 3: Commit and Push

```bash
git add database/migrations/20250701140000_add_org_id_columns.sql
git commit -m "Add org_id columns for multi-tenancy"
git push
```

#### Step 4: Apply via Otto

Tell Otto:
> "Apply database migrations from my repo"

Otto will:
1. Read `database/_migrations_index.json`
2. Find `20250701140000_add_org_id_columns.sql` as pending
3. Parse the SQL statements
4. Execute:
   ```
   db_alter_table({ table: "voice_profiles", changes: { addColumns: [{ name: "org_id", type: "text" }] } })
   db_alter_table({ table: "podcast_profiles", changes: { addColumns: [{ name: "org_id", type: "text" }] } })
   db_alter_table({ table: "speakers", changes: { addColumns: [{ name: "org_id", type: "text" }] } })
   db_alter_table({ table: "reels", changes: { addColumns: [{ name: "org_id", type: "text" }] } })
   db_alter_table({ table: "studio_episodes", changes: { addColumns: [{ name: "org_id", type: "text" }] } })
   db_alter_table({ table: "voice_profiles", changes: { addIndexes: [{ columns: ["org_id"] }] } })
   db_alter_table({ table: "speakers", changes: { addIndexes: [{ columns: ["org_id"] }] } })
   ```
5. Update `_migrations_index.json`

#### Step 5: Verify

Ask Otto:
> "Describe the voice_profiles table"

Otto confirms the new `org_id` column exists.

---

## Directory Structure Reference

```
throughline/
├── database/
│   ├── README.md                          # This contract document
│   ├── atlas.hcl                          # Atlas configuration
│   ├── schema.sql                         # Current schema definition (source of truth)
│   ├── docker-compose.yml                 # Local PostgreSQL setup
│   ├── _migrations_index.json             # Migration tracking (managed by Otto)
│   └── migrations/
│       ├── 20250701120000_initial.sql
│       ├── 20250701130000_add_voice_profiles.sql
│       └── 20250701140000_add_org_id_columns.sql
├── apps/
│   └── throughline/
│       └── App.tsx
├── hooks/
│   └── db-api.js
├── landing-pages/
│   └── landing.tsx
└── docs/
    └── AUDOS-DATABASE-MIGRATIONS-SDK.md   # This document (for reference)
```

---

## Atlas Configuration

### atlas.hcl

```hcl
# Atlas configuration for Throughline

variable "local_db_url" {
  type    = string
  default = "postgres://dev:dev@localhost:5432/throughline_dev?sslmode=disable"
}

env "local" {
  # Source of truth for schema
  src = "file://schema.sql"

  # Local development database
  url = var.local_db_url

  # Dev database for diffing (uses Docker)
  dev = "docker://postgres/15/dev"

  migration {
    dir = "file://migrations"
  }
}

env "production" {
  # Production has no direct URL - migrations applied via Otto
  src = "file://schema.sql"

  migration {
    dir = "file://migrations"
  }
}

lint {
  destructive {
    error = true  # Fail on destructive changes
  }
}
```

### Common Atlas Commands

```bash
# Initialize migration directory
atlas migrate init

# Create a new migration (diff current schema vs database)
atlas migrate diff migration_name \
  --env local

# Apply all pending migrations
atlas migrate apply --env local

# Check migration status
atlas migrate status --env local

# Validate migrations
atlas migrate validate --env local

# Generate schema from existing database
atlas schema inspect --env local > schema.sql
```

---

## Docker Setup

### docker-compose.yml

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: throughline_postgres
    environment:
      POSTGRES_DB: throughline_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d:ro  # Auto-apply on first run
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev -d throughline_dev"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Optional: pgAdmin for GUI access
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: throughline_pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@throughline.local
      PGADMIN_DEFAULT_PASSWORD: admin
    ports:
      - "5050:80"
    depends_on:
      - db

volumes:
  pgdata:
```

### Usage

```bash
# Start database
docker-compose up -d db

# Start with pgAdmin (optional)
docker-compose up -d

# View logs
docker-compose logs -f db

# Stop
docker-compose down

# Stop and remove data (clean slate)
docker-compose down -v

# Connect via psql
docker exec -it throughline_postgres psql -U dev -d throughline_dev
```

---

## Migration Tracking

### _migrations_index.json

This file tracks which migrations have been applied to the Audos platform. **Otto manages this file** — you should not edit it manually.

```json
{
  "schemaVersion": "1.0.0",
  "workspaceId": "8f1ad824-832f-4af8-b77e-ab931a250625",
  "applied": [
    {
      "version": "20250701120000",
      "name": "initial_schema",
      "appliedAt": "2025-07-01T12:00:00Z",
      "appliedBy": "otto",
      "checksum": "sha256:abc123...",
      "operationsApplied": 15
    },
    {
      "version": "20250701130000",
      "name": "add_voice_profiles",
      "appliedAt": "2025-07-01T13:00:00Z",
      "appliedBy": "otto",
      "checksum": "sha256:def456...",
      "operationsApplied": 3
    }
  ],
  "lastApplied": "2025-07-01T13:00:00Z",
  "errors": []
}
```

### Initial Setup

If `_migrations_index.json` doesn't exist, create it:

```json
{
  "schemaVersion": "1.0.0",
  "workspaceId": "YOUR_WORKSPACE_ID",
  "applied": [],
  "lastApplied": null,
  "errors": []
}
```

---

## Best Practices

### 1. Migration Naming Convention

```
YYYYMMDDHHMMSS_descriptive_name.sql
```

Examples:
- `20250701120000_initial_schema.sql`
- `20250701130000_add_voice_profiles_table.sql`
- `20250701140000_add_org_id_to_all_tables.sql`
- `20250701150000_create_analytics_tables.sql`

### 2. One Migration = One Logical Change

Don't mix unrelated changes in one migration:

```
❌ Bad:  20250701120000_add_users_and_fix_typo_and_new_index.sql
✅ Good: 20250701120000_add_users_table.sql
✅ Good: 20250701120100_fix_column_name_typo.sql
✅ Good: 20250701120200_add_performance_indexes.sql
```

### 3. Always Include Rollback Comments

Even if Otto can't auto-rollback, document how to undo:

```sql
-- migration: 20250701120000_add_feature
-- description: Add new feature table

CREATE TABLE feature (...);

-- rollback:
-- DROP TABLE feature;
```

### 4. Test Locally First

Always apply migrations to your local database before pushing:

```bash
atlas migrate apply --env local
# Verify everything works
git push
```

### 5. Handle Destructive Changes Carefully

For DROP operations, Otto will ask for confirmation. Plan for this in CI/CD.

### 6. Keep schema.sql Updated

After creating migrations, update your schema.sql to reflect the current state:

```bash
atlas schema inspect --env local > schema.sql
git add schema.sql
git commit -m "Update schema.sql to reflect migrations"
```

---

## Troubleshooting

### Migration Not Being Applied

**Symptom:** You pushed a migration but Otto says "no pending migrations"

**Check:**
1. Is the file in `database/migrations/`?
2. Does the filename match pattern `YYYYMMDDHHMMSS_name.sql`?
3. Is it already in `_migrations_index.json` applied list?
4. Did GitHub sync complete?

### Schema Mismatch

**Symptom:** Local schema differs from Audos schema

**Solution:**
1. Ask Otto: "Describe all database tables"
2. Compare with your local schema
3. Create a reconciliation migration if needed

### Operation Not Supported

**Symptom:** Otto says "I can't perform this operation"

**Check:** Review the [Unsupported Operations](#unsupported-operations--workarounds) section for workarounds.

### Partial Migration Failure

**Symptom:** Some operations succeeded, others failed

**What Happens:**
- Successful operations are committed
- Failed operations are logged in `_migrations_index.json` errors array
- You'll need to fix and create a follow-up migration

---

## Appendix: Current Schema

### Tables in Throughline Workspace (as of July 2025)

| Table | Description | Columns |
|-------|-------------|---------|
| `voice_profiles` | Voice fingerprints for hosts and brands | 14 |
| `dashboard_activity` | Activity feed for dashboard | 11 |
| `guest_prep_podcast_profiles` | Podcast identity configuration | 17 |
| `guest_prep_research_sessions` | Per-episode guest research | 26 |
| `guest_prep_ros_versions` | Run of Show version history | 8 |
| `briefing_podcast_profiles` | Briefing app podcast profiles | 15 |
| `briefing_research_sessions` | Briefing research sessions | 20 |
| `speakers` | Speaker registry for transcripts | 14 |
| `reels` | Social media content pieces | 15 |
| `reel_captions` | Generated captions per platform | 14 |
| `voice_refinements` | Voice model training data | 13 |
| `studio_episodes` | Episode drops for content gen | 13 |
| `studio_time_tracking` | Time saved tracking | 8 |
| `studio_generated_content` | Generated content per platform | 15 |
| `outreach_leads` | Podcast creator leads | 18 |
| `linked_references` | Cached web pages | 9 |
| `podcast_setup_profiles` | Setup wizard profiles | 15 |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-07-01 | Otto | Initial SDK document |

---

## Questions?

Ask Otto:
- "What tables exist in my database?"
- "Describe the voice_profiles table"
- "Apply database migrations from my repo"
- "What migrations are pending?"

---

*This document is part of the Throughline SDK. Keep it updated as the migration workflow evolves.*

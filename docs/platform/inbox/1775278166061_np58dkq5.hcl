# Atlas Configuration for Throughline
# ====================================
#
# Atlas is a database schema management tool.
# Install: brew install ariga/tap/atlas
# Docs: https://atlasgo.io/

variable "local_db_url" {
  type    = string
  default = "postgres://dev:dev@localhost:5432/throughline_dev?sslmode=disable"
}

# Local development environment
env "local" {
  # Source of truth for schema
  src = "file://schema.sql"

  # Local development database
  url = var.local_db_url

  # Dev database for diffing (uses Docker - spins up temp container)
  dev = "docker://postgres/15/dev"

  migration {
    dir = "file://migrations"
  }

  # Exclude system tables from diffing
  exclude = ["atlas_schema_revisions"]
}

# Production environment (Audos)
# NOTE: No direct URL - migrations applied via Otto
env "production" {
  src = "file://schema.sql"

  migration {
    dir = "file://migrations"
  }
}

# Linting rules
lint {
  # Fail on destructive changes (require explicit confirmation)
  destructive {
    error = true
  }

  # Data-dependent changes require review
  data_depend {
    error = true
  }
}

# Diff settings
diff {
  # Skip comparing certain attributes
  skip {
    # Don't diff on table comments
    # drop_table = true
  }
}

# ============================================
# Common Commands
# ============================================
#
# Initialize migrations directory:
#   atlas migrate init
#
# Create new migration from schema changes:
#   atlas migrate diff migration_name --env local
#
# Apply migrations to local database:
#   atlas migrate apply --env local
#
# Check migration status:
#   atlas migrate status --env local
#
# Validate migrations are correct:
#   atlas migrate validate --env local
#
# Generate schema.sql from existing database:
#   atlas schema inspect --env local > schema.sql
#
# Hash existing migrations (after manual edits):
#   atlas migrate hash --env local
#
# ============================================

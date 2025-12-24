# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PostgreSQL event trigger that automatically enables Row Level Security (RLS) with FORCE option on all newly-created tables in the public schema. Designed for Supabase projects where forgetting to enable RLS can expose data.

## Commands

### Local Development
```bash
supabase start              # Start local Supabase
supabase db reset           # Apply migrations (enables the trigger)
supabase test db            # Run pgTAP tests (34 tests)
```

### Deploy to Hosted Project
```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

### Standalone PostgreSQL (non-Supabase)
```bash
psql -f install.sql         # Install trigger
psql -f uninstall.sql       # Remove trigger
```

## Architecture

The project consists of a single PostgreSQL event trigger:

1. **Event Trigger** (`enable_rls_trigger`): Fires on `ddl_command_end` for `CREATE TABLE`, `CREATE TABLE AS`, and `SELECT INTO` commands
2. **Trigger Function** (`enable_rls_on_new_tables()`): Checks if new table is in `public` schema, then executes `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and `ALTER TABLE ... FORCE ROW LEVEL SECURITY`

Key files:
- `supabase/migrations/20241224000000_enable_rls_trigger.sql` - Supabase migration
- `install.sql` / `uninstall.sql` - Standalone installation scripts
- `supabase/tests/00001_rls_trigger_test.sql` - pgTAP test suite

## Important Behavior

- Only affects tables in `public` schema; other schemas are ignored
- Only affects **new** tables created after installation; existing tables unchanged
- Tables still need RLS policies created; this just enables the mechanism
- Tables without policies deny all access (except to superusers/owners without FORCE)

## Verification Query

```sql
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname = 'your_table_name';
```

Both `relrowsecurity` and `relforcerowsecurity` should be `t` (true).

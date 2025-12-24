# enable-rls-automatically

PostgreSQL event trigger that automatically enables Row Level Security (RLS) with FORCE option on all newly-created tables in the public schema.

## Why?

Supabase uses RLS as its primary access control mechanism. Forgetting to enable RLS on a table can expose data to unauthorized access. This event trigger ensures every new table in the public schema has RLS enabled by default.

The `FORCE` option ensures RLS policies apply even to table owners (like the `postgres` role), which is important in Supabase where service roles bypass RLS by default.

## Requirements

- Supabase project (local or hosted)
- Supabase CLI (`supabase --version` >= 1.0)
- Docker (for local development)

## Quick Start

### Local Development

```bash
# Start local Supabase
supabase start

# Apply migration (enables the trigger)
supabase db reset

# Run tests
supabase test db
```

### Deploy to Hosted Project

```bash
# Link to your project
supabase link --project-ref <your-project-ref>

# Push migration
supabase db push
```

## Usage

Once deployed, RLS is automatically enabled on any new table created in the public schema:

```sql
CREATE TABLE public.users (id int, email text);
-- NOTICE: RLS enabled with FORCE on table: public.users
```

Tables in other schemas are not affected:

```sql
CREATE TABLE private.internal_data (id int);
-- No RLS applied
```

## Verify

Check that RLS is enabled on a table:

```sql
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname = 'your_table_name';
```

Both `relrowsecurity` and `relforcerowsecurity` should be `t` (true).

## How It Works

1. An event trigger fires on `ddl_command_end` after `CREATE TABLE` or `ALTER TABLE` statements
2. The trigger function checks if the table is in the `public` schema
3. If so, and RLS is not already enabled, it executes:
   - `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
   - `ALTER TABLE ... FORCE ROW LEVEL SECURITY`

This also catches tables moved into `public` via `ALTER TABLE ... SET SCHEMA public`.

## Implementation

The complete implementation after all migrations:

```sql
-- Trigger function
CREATE OR REPLACE FUNCTION public.enable_rls_on_new_tables()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    obj record;
    table_oid oid;
    rls_status record;
BEGIN
    -- Prevent infinite recursion
    IF current_setting('enable_rls.in_trigger', true) = 'true' THEN
        RETURN;
    END IF;

    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
        WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE')
          AND object_type = 'table'
    LOOP
        IF obj.schema_name = 'public' THEN
            table_oid := obj.object_identity::regclass::oid;

            SELECT relrowsecurity, relforcerowsecurity
            INTO rls_status
            FROM pg_class
            WHERE oid = table_oid;

            IF rls_status.relrowsecurity AND rls_status.relforcerowsecurity THEN
                RAISE NOTICE 'RLS with FORCE already enabled on table: %', obj.object_identity;
            ELSE
                PERFORM set_config('enable_rls.in_trigger', 'true', true);
                EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', obj.object_identity);
                EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY', obj.object_identity);
                PERFORM set_config('enable_rls.in_trigger', 'false', true);
                RAISE NOTICE 'RLS enabled with FORCE on table: %', obj.object_identity;
            END IF;
        END IF;
    END LOOP;
END;
$$;

-- Event trigger
CREATE EVENT TRIGGER enable_rls_trigger
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE')
EXECUTE FUNCTION public.enable_rls_on_new_tables();
```

## Project Structure

```
enable-rls-automatically/
├── supabase/
│   ├── config.toml              # Supabase configuration
│   ├── migrations/
│   │   └── 20241224000000_enable_rls_trigger.sql
│   └── tests/
│       └── 00001_rls_trigger_test.sql
└── README.md
```

## Testing

The test suite uses [pgTAP](https://pgtap.org/) via `supabase test db`.

### Run Tests Locally

```bash
# Ensure local Supabase is running
supabase start

# Run all tests (41 tests)
supabase test db
```

### Test Coverage

| Category                  | Tests | Description                                            |
|---------------------------|-------|--------------------------------------------------------|
| Installation Verification | 4     | Function/trigger existence, correct event binding      |
| Core Functionality        | 4     | RLS + FORCE enabled on basic/constrained tables        |
| Schema Filtering          | 4     | public only; temp/private/auth ignored                 |
| CREATE TABLE Variants     | 6     | CTAS, LIKE, IF NOT EXISTS, UNLOGGED, partitioned       |
| Non-Triggering DDL        | 5     | Views, matviews, INDEX, SEQUENCE, ALTER TABLE behavior |
| Edge Cases                | 5     | Special chars, mixed case, reserved words, idempotency |
| Transaction Behavior      | 2     | Savepoint rollback, visibility                         |
| Uninstall Verification    | 4     | Disable/enable trigger, behavior changes               |
| ALTER TABLE SET SCHEMA    | 5     | Tables moved into public get RLS enabled               |
| Forbid Disabling RLS      | 2     | DISABLE/NO FORCE immediately re-enabled                |

## Important Notes

- This affects **new** tables created after installation
- Foreign tables are not affected (PostgreSQL does not support RLS on foreign tables)
- Tables moved into `public` via `ALTER TABLE ... SET SCHEMA` also get RLS enabled
- **Disabling RLS is forbidden**: `DISABLE ROW LEVEL SECURITY` and `NO FORCE ROW LEVEL SECURITY` are immediately reversed
- Existing tables are not modified; enable RLS on them manually if needed
- You still need to create RLS policies for the tables; this just enables the RLS mechanism
- Tables without policies will deny all access (except to superusers/owners without FORCE)

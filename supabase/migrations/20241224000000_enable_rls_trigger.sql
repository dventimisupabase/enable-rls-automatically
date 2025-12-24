-- Enable RLS automatically on tables in public schema
--
-- This event trigger automatically enables Row Level Security (RLS) with FORCE
-- option on all newly-created tables in the public schema, as well as tables
-- moved into the public schema via ALTER TABLE ... SET SCHEMA.

-- Function that enables RLS on tables in public schema
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
    -- Prevent infinite recursion: our ALTER TABLE commands would re-trigger this function
    -- Use a session variable to track if we're already in the trigger
    IF current_setting('enable_rls.in_trigger', true) = 'true' THEN
        RETURN;
    END IF;

    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
        WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE')
          AND object_type = 'table'
    LOOP
        -- Only apply to public schema
        IF obj.schema_name = 'public' THEN
            table_oid := obj.object_identity::regclass::oid;

            SELECT relrowsecurity, relforcerowsecurity
            INTO rls_status
            FROM pg_class
            WHERE oid = table_oid;

            IF rls_status.relrowsecurity AND rls_status.relforcerowsecurity THEN
                RAISE NOTICE 'RLS with FORCE already enabled on table: %', obj.object_identity;
            ELSE
                -- Set flag to prevent recursion before executing ALTER TABLE
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

-- Event trigger that fires after table creation or modification
CREATE EVENT TRIGGER enable_rls_trigger
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE')
EXECUTE FUNCTION public.enable_rls_on_new_tables();

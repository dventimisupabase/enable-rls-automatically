-- Enable RLS automatically on new tables in public schema
--
-- This event trigger automatically enables Row Level Security (RLS) with FORCE
-- option on all newly-created tables in the public schema.

-- Function that enables RLS on newly created tables
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
    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
        WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
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
                EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', obj.object_identity);
                EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY', obj.object_identity);
                RAISE NOTICE 'RLS enabled with FORCE on table: %', obj.object_identity;
            END IF;
        END IF;
    END LOOP;
END;
$$;

-- Event trigger that fires after CREATE TABLE (includes CREATE TABLE AS and SELECT INTO)
CREATE EVENT TRIGGER enable_rls_trigger
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
EXECUTE FUNCTION public.enable_rls_on_new_tables();

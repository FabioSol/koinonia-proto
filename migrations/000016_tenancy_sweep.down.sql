ALTER TABLE spaces ALTER COLUMN tenant_id DROP DEFAULT;
ALTER TABLE nodes  ALTER COLUMN tenant_id DROP DEFAULT;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'node_history','checkpoints','principals','group_members','space_grants',
    'node_authors','comments','reactions','reports','search_index','embeds',
    'git_sync_jobs','space_origins','y_updates','coedit_locks','export_jobs'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I', t);
    EXECUTE format('ALTER TABLE %I NO FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP INDEX IF EXISTS %I', t || '_tenant');
    EXECUTE format('ALTER TABLE %I DROP COLUMN IF EXISTS tenant_id', t);
  END LOOP;
END $$;

-- 000016_tenancy_sweep (ADR-0033, S42): extend tenant_id + Row-Level Security to
-- every remaining tenant-scoped table, and give tenant_id a DEFAULT that reads the
-- connection's app.tenant GUC — so INSERTs auto-stamp the current tenant (satisfying
-- the RLS WITH CHECK) without editing every store INSERT. Existing rows keep NULL
-- until the S43 backfill (invisible to the app role under RLS; visible to superusers).
--
-- blobs is intentionally excluded: it is a content-addressed size registry whose
-- per-owner tenancy + object-store prefix land together in S56.

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'node_history','checkpoints','principals','group_members','space_grants',
    'node_authors','comments','reactions','reports','search_index','embeds',
    'git_sync_jobs','space_origins','y_updates','coedit_locks','export_jobs'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS tenant_id UUID', t);
    EXECUTE format(
      $d$ALTER TABLE %I ALTER COLUMN tenant_id SET DEFAULT nullif(current_setting('app.tenant', true), '')::uuid$d$, t);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I (tenant_id)', t || '_tenant', t);
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format(
      $p$CREATE POLICY tenant_isolation ON %I
        USING      (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)
        WITH CHECK (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)$p$, t);
  END LOOP;
END $$;

-- spaces + nodes already carry tenant_id + RLS (000015); give them the same
-- auto-stamping DEFAULT so tenant-bound INSERTs populate tenant_id too.
ALTER TABLE spaces ALTER COLUMN tenant_id SET DEFAULT nullif(current_setting('app.tenant', true), '')::uuid;
ALTER TABLE nodes  ALTER COLUMN tenant_id SET DEFAULT nullif(current_setting('app.tenant', true), '')::uuid;

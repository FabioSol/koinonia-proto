-- 000015_tenancy_tracer (ADR-0033, S41): the thin end of multi-tenancy. Add
-- tenant_id + Row-Level Security to spaces + nodes ONLY (the rest of the tenant
-- schema follows in S42), and create the non-superuser app role that runtime
-- connections use so RLS is actually enforced (a superuser bypasses RLS).
--
-- Existing rows keep tenant_id = NULL until the S43 backfill; under RLS a NULL
-- tenant_id matches no app.tenant, so those rows are invisible to the app role
-- (superuser/migration connections still see them). New tenant rows set tenant_id.

ALTER TABLE spaces ADD COLUMN tenant_id UUID;
ALTER TABLE nodes  ADD COLUMN tenant_id UUID;
CREATE INDEX nodes_tenant  ON nodes  (tenant_id);
CREATE INDEX spaces_tenant ON spaces (tenant_id);

-- Enable + FORCE so even the table owner is subject to policies; the app role is a
-- non-owner non-superuser, so RLS applies to it regardless.
ALTER TABLE spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE spaces FORCE ROW LEVEL SECURITY;
ALTER TABLE nodes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE nodes  FORCE ROW LEVEL SECURITY;

-- current_setting(..., true) => NULL when unset (fail-closed: no tenant => no rows).
CREATE POLICY tenant_isolation ON spaces
  USING       (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)
  WITH CHECK  (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid);
CREATE POLICY tenant_isolation ON nodes
  USING       (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)
  WITH CHECK  (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid);

-- Runtime app role: LOGIN, NOT superuser (so RLS is enforced), NOT the table owner.
-- Shard DSNs connect as this role. Password is dev-only; override in real deploys.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'koinonia_app') THEN
    CREATE ROLE koinonia_app LOGIN PASSWORD 'koinonia_app';
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO koinonia_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO koinonia_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO koinonia_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO koinonia_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO koinonia_app;

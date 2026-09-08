DROP POLICY IF EXISTS tenant_isolation ON nodes;
DROP POLICY IF EXISTS tenant_isolation ON spaces;
ALTER TABLE nodes  NO FORCE ROW LEVEL SECURITY;
ALTER TABLE nodes  DISABLE ROW LEVEL SECURITY;
ALTER TABLE spaces NO FORCE ROW LEVEL SECURITY;
ALTER TABLE spaces DISABLE ROW LEVEL SECURITY;
DROP INDEX IF EXISTS nodes_tenant;
DROP INDEX IF EXISTS spaces_tenant;
ALTER TABLE nodes  DROP COLUMN IF EXISTS tenant_id;
ALTER TABLE spaces DROP COLUMN IF EXISTS tenant_id;
-- koinonia_app role is left in place (cluster-global; may own grants elsewhere).

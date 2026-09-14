-- S63: tighten blobs RLS so NULL-tenant rows are not visible across tenants.
-- PREREQUISITE: run koinonia-backfill first; after the backfill all referenced
-- NULL rows have been stamped and deleted, so no live read path depends on the
-- old cross-tenant NULL visibility.
--
-- Old policy: tenant_id IS NULL makes rows visible to ALL tenant contexts
--             (cross-tenant existence oracle).
-- New policy: NULL rows visible ONLY when app.tenant GUC is unset — i.e. the
--             single-tenant / GC / no-context code path. Closes the oracle while
--             preserving single-tenant GC (GUC empty → matches NULL rows).
--
-- Verification:
--   GUC empty (''): nullif('','') = NULL, NULL::uuid IS NOT DISTINCT FROM NULL → true (NULL rows visible for GC) ✓
--   GUC = tenant UUID: nullif(uuid,'') = uuid, tenant_id IS NOT DISTINCT FROM uuid → tenant-specific only ✓

ALTER POLICY blobs_tenant ON blobs
  USING  (tenant_id IS NOT DISTINCT FROM nullif(current_setting('app.tenant', true), '')::uuid)
  WITH CHECK (tenant_id IS NOT DISTINCT FROM nullif(current_setting('app.tenant', true), '')::uuid);

-- S56: namespace blobs by owner (ADR-0033).
-- Adds tenant_id (auto-filled from the app.tenant GUC set by the tenant router) and
-- Row-Level Security so each tenant sees only its own blob registry rows.
-- NULL tenant_id = "global" / legacy blob (no tenant context) — compatible with the
-- no-control-plane dev mode and with all rows that existed before this migration.
-- The hash column is no longer globally unique (two tenants may store different blobs
-- under the same content hash at different S3 keys); uniqueness is per (tenant_id, hash)
-- for non-NULL tenants, and per hash for the legacy NULL bucket.

ALTER TABLE blobs DROP CONSTRAINT blobs_pkey;

-- Surrogate PK to keep FK semantics (nothing currently references blobs.hash, but
-- keeps the table well-formed).
ALTER TABLE blobs ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY;

-- tenant_id: auto-filled from the GUC; NULL for connections without tenant context.
ALTER TABLE blobs ADD COLUMN tenant_id uuid
  DEFAULT nullif(current_setting('app.tenant', true), '')::uuid;

-- Two partial unique indexes mirror the two uniqueness regimes:
--   • NULL-tenant bucket: hash must be unique (dedup for legacy / global blobs).
--   • Non-NULL tenant bucket: (tenant_id, hash) must be unique per owner.
CREATE UNIQUE INDEX blobs_hash_null_uq   ON blobs (hash)            WHERE tenant_id IS NULL;
CREATE UNIQUE INDEX blobs_tenant_hash_uq ON blobs (tenant_id, hash) WHERE tenant_id IS NOT NULL;

ALTER TABLE blobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE blobs FORCE ROW LEVEL SECURITY;

-- Allow access to the row when either:
--   (a) it has no tenant_id (global/legacy — visible to all connections), OR
--   (b) its tenant_id matches the current connection's app.tenant GUC.
CREATE POLICY blobs_tenant ON blobs
  USING  (tenant_id IS NULL OR tenant_id::text = current_setting('app.tenant', true))
  WITH CHECK (tenant_id IS NULL OR tenant_id::text = current_setting('app.tenant', true));

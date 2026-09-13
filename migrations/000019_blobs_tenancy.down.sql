DROP POLICY  blobs_tenant ON blobs;
ALTER TABLE  blobs DISABLE ROW LEVEL SECURITY;
DROP INDEX   blobs_tenant_hash_uq;
DROP INDEX   blobs_hash_null_uq;
ALTER TABLE  blobs DROP COLUMN tenant_id;
ALTER TABLE  blobs DROP COLUMN id;
ALTER TABLE  blobs ADD CONSTRAINT blobs_pkey PRIMARY KEY (hash);

ALTER POLICY blobs_tenant ON blobs
  USING  (tenant_id IS NULL OR tenant_id::text = current_setting('app.tenant', true))
  WITH CHECK (tenant_id IS NULL OR tenant_id::text = current_setting('app.tenant', true));

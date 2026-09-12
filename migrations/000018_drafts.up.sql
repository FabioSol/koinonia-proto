-- 000018_drafts: named draft lifecycle table for the S51 Drafts-as-branches UI
-- (ADR-0027). Each row represents a named draft (open|merged|discarded); its UUID
-- doubles as the draft_id TEXT used in nodes/y_updates/coedit_locks, which store it
-- as plain text without an FK — intentional (nodes are deleted on merge/discard).

CREATE TABLE drafts (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID        NOT NULL DEFAULT nullif(current_setting('app.tenant', true), '')::uuid,
  space_id    UUID        NOT NULL,
  name        TEXT        NOT NULL,
  created_by  TEXT        NOT NULL,
  state       TEXT        NOT NULL DEFAULT 'open'
                          CHECK (state IN ('open', 'merged', 'discarded')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX drafts_space ON drafts (space_id, state);
CREATE INDEX drafts_tenant ON drafts (tenant_id);

ALTER TABLE drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE drafts FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON drafts
  USING      (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)
  WITH CHECK (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid);

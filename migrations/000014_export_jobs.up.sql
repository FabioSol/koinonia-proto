-- 000014_export_jobs: async document export (PDF/ZIP) jobs (ADR-0025). A worker
-- renders a subtree to PDF (goldmark→HTML→PDF, display-config aware) or bundles it
-- as a ZIP of blobs at their paths, stores the artifact in S3, and exposes it via a
-- short-lived signed URL. Distinct from git_sync_jobs (which pushes to a git remote).

CREATE TABLE export_jobs (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    space_id     UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    root_logical UUID NOT NULL,                  -- subtree root (space root = whole space)
    format       TEXT NOT NULL CHECK (format IN ('pdf','zip')),
    state        TEXT NOT NULL DEFAULT 'pending', -- pending|running|succeeded|failed
    progress     INT  NOT NULL DEFAULT 0,        -- 0..100
    detail       TEXT,                           -- current step
    error        TEXT,                           -- populated on failure
    artifact_key TEXT,                           -- S3 object key of the result
    requested_by TEXT NOT NULL,                  -- actor handle
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX export_jobs_space ON export_jobs (space_id, created_at);

-- 000011_git_sync: async git import/export jobs + per-space origin linkage
-- (ADR-0029/0030/0031). git_sync_jobs tracks a long-running clone/replay or
-- export; space_origins remembers the remote + last-synced SHA that makes export
-- symmetric (diff since import).

CREATE TABLE git_sync_jobs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    space_id   UUID,                         -- set once the space exists
    kind       TEXT NOT NULL,                -- 'import' | 'export'
    state      TEXT NOT NULL DEFAULT 'pending', -- pending|running|succeeded|failed
    progress   INT  NOT NULL DEFAULT 0,      -- 0..100
    detail     TEXT,                         -- current step
    error      TEXT,                         -- populated on failure
    result     TEXT,                         -- space id / repo / PR url
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX git_sync_jobs_space ON git_sync_jobs (space_id, created_at);

CREATE TABLE space_origins (
    space_id        UUID PRIMARY KEY REFERENCES spaces(id) ON DELETE CASCADE,
    remote          TEXT NOT NULL,
    default_branch  TEXT NOT NULL DEFAULT 'main',
    last_synced_sha TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

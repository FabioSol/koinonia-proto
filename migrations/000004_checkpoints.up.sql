-- 000004_checkpoints: named time-travel tags. A checkpoint pins a global commit
-- seq for a branch of a space (ADR-0016), surfaced under .history/<name>.

CREATE TABLE checkpoints (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    space_id   UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    branch     TEXT NOT NULL DEFAULT 'main',  -- 'main' or a draft_id
    name       TEXT NOT NULL,
    as_of_seq  BIGINT NOT NULL,
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (space_id, branch, name)
);

-- 000003_node_history: the immutable, append-only ledger behind traceability and
-- time travel (ADR-0016). Every CAS/create/delete appends one row in the SAME
-- transaction as the HEAD update. Structural columns (parent_id, name, kind,
-- is_deleted) are versioned too, so past tree state (renames/moves/deletes) can
-- be reconstructed. `seq` is a global monotonic commit order for whole-tree
-- snapshots; per-node history uses `version`.

CREATE TABLE node_history (
    history_id      BIGSERIAL PRIMARY KEY,
    seq             BIGSERIAL,                    -- global monotonic commit order
    logical_id      UUID NOT NULL,
    space_id        UUID NOT NULL,
    draft_id        TEXT,
    version         INTEGER NOT NULL,
    content_hash    TEXT,
    frontmatter     JSONB NOT NULL DEFAULT '{}',
    parent_id       UUID,                         -- parent's logical_id (as in nodes)
    name            TEXT,
    kind            TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    updated_by      TEXT,
    actor           TEXT,
    obo             TEXT,                          -- on-behalf-of user for agent writes
    source_draft_id TEXT,                          -- draft that published this main version
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX nh_asof ON node_history (logical_id, seq);
CREATE INDEX nh_time ON node_history (space_id, created_at);
CREATE INDEX nh_hash ON node_history (content_hash); -- strong blob reference for GC

# koinonia-proto ADR-0001 — Concrete schema: `nodes`, `node_history`, `blobs`, `spaces`

**Status:** Accepted · Implements general ADR-0007, 0008, 0010, 0016, 0017, 0018

Illustrative DDL (Postgres 15+). Exact types/indexes are refined during migration authoring; the constraints marked **must** encode the correctness carry-forwards.

```sql
CREATE TABLE spaces (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug          TEXT UNIQUE NOT NULL,
    settings      JSONB NOT NULL DEFAULT '{}',  -- json-schema, display default,
                                                -- hide_expired, default_ttl,
                                                -- require_drafts_for_main
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Mutable HEAD (fast Lookup / CAS target)
CREATE TABLE nodes (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    logical_id    UUID NOT NULL,               -- stable identity across versions/drafts
    space_id      UUID NOT NULL REFERENCES spaces(id),
    parent_id     UUID REFERENCES nodes(id),   -- NULL = root
    name          TEXT NOT NULL,
    kind          TEXT NOT NULL CHECK (kind IN ('space','section','article','folder')),
    draft_id      TEXT,                         -- NULL = main
    content_hash  TEXT,                         -- SHA-256; NULL for pure folders
    frontmatter   JSONB NOT NULL DEFAULT '{}',
    version       INTEGER NOT NULL DEFAULT 1,
    base_version  INTEGER,                      -- main version a draft row forked from
    is_deleted    BOOLEAN NOT NULL DEFAULT false,
    updated_by    TEXT,                         -- user id
    actor         TEXT,                         -- agent id or user id
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- MUST: prevent duplicate MAIN siblings (NULLs would otherwise be distinct)
CREATE UNIQUE INDEX nodes_sibling_uniq
    ON nodes (parent_id, name, draft_id) NULLS NOT DISTINCT;

CREATE INDEX nodes_lookup ON nodes (parent_id, name, draft_id);
CREATE INDEX nodes_logical ON nodes (logical_id, draft_id);

-- Immutable append-only ledger (traceability + time travel)
CREATE TABLE node_history (
    history_id     BIGSERIAL PRIMARY KEY,
    seq            BIGSERIAL,                   -- GLOBAL monotonic commit order (tree snapshots)
    logical_id     UUID NOT NULL,
    space_id       UUID NOT NULL,
    draft_id       TEXT,
    version        INTEGER NOT NULL,
    content_hash   TEXT,
    frontmatter    JSONB NOT NULL DEFAULT '{}',
    parent_id      UUID,                        -- structural columns: required to
    name           TEXT,                        -- reconstruct renames/moves/deletes
    is_deleted     BOOLEAN NOT NULL DEFAULT false,
    kind           TEXT,
    updated_by     TEXT,
    actor          TEXT,
    obo            TEXT,                         -- on-behalf-of user for agent writes
    source_draft_id TEXT,                        -- which draft published this main version
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX nh_asof ON node_history (logical_id, seq);
CREATE INDEX nh_time ON node_history (space_id, created_at);
CREATE INDEX nh_hash ON node_history (content_hash);  -- strong blob reference for GC

-- Blob registry (dedup "know this hash?" + GC bookkeeping)
CREATE TABLE blobs (
    hash          TEXT PRIMARY KEY,            -- SHA-256
    size_bytes    BIGINT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Canonical overlay resolution (MUST use `NULLS LAST`)

```sql
-- Lookup one component:
SELECT * FROM nodes
 WHERE parent_id = $1 AND name = $2 AND (draft_id = $3 OR draft_id IS NULL)
 ORDER BY draft_id DESC NULLS LAST
 LIMIT 1;   -- then: if is_deleted -> ENOENT

-- ReadDir with overlay:
SELECT DISTINCT ON (logical_id) *
  FROM nodes
 WHERE parent_id = $1 AND (draft_id = $2 OR draft_id IS NULL)
 ORDER BY logical_id, draft_id DESC NULLS LAST;  -- then filter is_deleted

-- Time travel (tree as-of global seq N):
SELECT DISTINCT ON (logical_id) *
  FROM node_history
 WHERE space_id = $1 AND seq <= $2
 ORDER BY logical_id, seq DESC;                  -- then filter is_deleted
```

## Consequences

- Encodes the two critical carry-forwards (NULLS-LAST ordering, NULLS-NOT-DISTINCT uniqueness) directly in schema/queries.
- `node_history.content_hash` index makes the GC "strong reference" check cheap (general ADR-0017).
- `seq` gives whole-tree snapshot handles; per-node `version` addresses single-file history.

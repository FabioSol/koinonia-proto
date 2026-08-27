-- 000001_init: core namespace tables (spaces, nodes, blobs) for Koinonia v0.
-- Requires PostgreSQL 15+ (NULLS NOT DISTINCT).
-- Refs: docs/adrs/0001-schema-nodes-and-history.md; general ADR-0006, ADR-0007.

CREATE TABLE spaces (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug       TEXT UNIQUE NOT NULL,
    settings   JSONB NOT NULL DEFAULT '{}',  -- json-schema, display default,
                                             -- hide_expired, default_ttl,
                                             -- require_drafts_for_main
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Mutable HEAD (fast FUSE Lookup / CAS target).
CREATE TABLE nodes (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    logical_id   UUID NOT NULL,                 -- stable identity across versions/drafts
    space_id     UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    parent_id    UUID,                           -- parent's LOGICAL id (NULL = root).
                                                 -- No FK: logical_id is not unique
                                                 -- (a node has many rows across
                                                 -- versions/drafts), so children must
                                                 -- reference the stable logical id, and
                                                 -- FUSE navigates by it.
    name         TEXT NOT NULL,
    kind         TEXT NOT NULL CHECK (kind IN ('space','section','article','folder')),
    draft_id     TEXT,                          -- NULL = main
    content_hash TEXT,                          -- SHA-256; NULL for pure folders
    frontmatter  JSONB NOT NULL DEFAULT '{}',
    version      INTEGER NOT NULL DEFAULT 1,
    base_version INTEGER,                        -- main version a draft row forked from
    is_deleted   BOOLEAN NOT NULL DEFAULT false, -- tombstone (never hard DELETE)
    updated_by   TEXT,
    actor        TEXT,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Prevent duplicate siblings. NULLS NOT DISTINCT so two MAIN rows (draft_id NULL)
-- with the same (parent_id, name) are actually rejected (see ADR-0007 carry-forward).
CREATE UNIQUE INDEX nodes_sibling_uniq
    ON nodes (parent_id, name, draft_id) NULLS NOT DISTINCT;

-- FUSE Lookup pattern: parent + name within a draft context.
CREATE INDEX nodes_lookup  ON nodes (parent_id, name, draft_id);
CREATE INDEX nodes_logical ON nodes (logical_id, draft_id);

-- Content-addressed blob registry (backs the "know this hash?" dedup pre-check).
CREATE TABLE blobs (
    hash       TEXT PRIMARY KEY,                -- SHA-256
    size_bytes BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

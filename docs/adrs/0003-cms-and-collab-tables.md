# koinonia-proto ADR-0003 — CMS, identity, search & collab tables

**Status:** Accepted · Implements general ADR-0020, 0021, 0022, 0023, 0025, 0027

Illustrative DDL for the browser/CMS layer and the collab sidecar's persistence.

```sql
-- Identity & RBAC (general ADR-0020) -----------------------------------------
CREATE TABLE principals (
    id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind   TEXT NOT NULL CHECK (kind IN ('user','group')),
    handle TEXT UNIQUE NOT NULL
);
CREATE TABLE group_members (
    group_id  UUID REFERENCES principals(id),
    member_id UUID REFERENCES principals(id),
    PRIMARY KEY (group_id, member_id)
);
CREATE TABLE space_grants (
    principal_id UUID REFERENCES principals(id),
    space_id     UUID REFERENCES spaces(id),
    role         TEXT NOT NULL CHECK (role IN ('viewer','contributor','editor','owner')),
    PRIMARY KEY (principal_id, space_id)
);
-- Authorship = pure attribution, decoupled from edit rights
CREATE TABLE node_authors (
    logical_id   UUID NOT NULL,
    principal_id UUID REFERENCES principals(id),
    PRIMARY KEY (logical_id, principal_id)
);

-- Engagement layer (general ADR-0021) ---------------------------------------
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    logical_id UUID NOT NULL,
    author_principal UUID REFERENCES principals(id),
    body TEXT NOT NULL,
    parent_comment_id UUID REFERENCES comments(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);
CREATE TABLE reactions (
    logical_id UUID NOT NULL,
    principal_id UUID REFERENCES principals(id),
    kind TEXT NOT NULL,
    PRIMARY KEY (logical_id, principal_id, kind)
);
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    logical_id UUID NOT NULL,
    reporter UUID REFERENCES principals(id),
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open'
);

-- Embeds (general ADR-0022) -------------------------------------------------
CREATE TABLE embeds (
    slug TEXT PRIMARY KEY,            -- opaque, signed
    logical_id UUID NOT NULL,
    mode TEXT NOT NULL CHECK (mode IN ('live','pinned')),
    pinned_seq BIGINT,               -- when mode='pinned'
    created_by UUID REFERENCES principals(id),
    revoked_at TIMESTAMPTZ
);

-- Time-travel tags (general ADR-0016) ---------------------------------------
CREATE TABLE checkpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    space_id UUID REFERENCES spaces(id),
    branch TEXT NOT NULL,            -- 'main' or draft_id
    name TEXT NOT NULL,
    as_of_seq BIGINT,
    as_of_time TIMESTAMPTZ,
    created_by UUID REFERENCES principals(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (space_id, branch, name)
);

-- Search (general ADR-0023) -------------------------------------------------
CREATE TABLE search_index (
    logical_id UUID NOT NULL,
    space_id UUID NOT NULL,
    draft_id TEXT,
    tsv TSVECTOR,
    fm_facets JSONB NOT NULL DEFAULT '{}',
    expiry_date TIMESTAMPTZ,          -- so search honors hide_expired
    PRIMARY KEY (logical_id, draft_id)
    -- future: embedding VECTOR(1536) for pgvector hybrid
);
CREATE INDEX search_tsv ON search_index USING GIN (tsv);

-- Export jobs (general ADR-0025) --------------------------------------------
CREATE TABLE export_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requested_by UUID REFERENCES principals(id),
    node_logical_id UUID NOT NULL,
    format TEXT NOT NULL CHECK (format IN ('pdf','zip')),
    status TEXT NOT NULL DEFAULT 'queued',
    result_url TEXT,                  -- signed S3 URL when done
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CRDT persistence (general ADR-0027, owned/written by koinonia-collab) ------
CREATE TABLE y_updates (
    draft_id TEXT NOT NULL,
    logical_id UUID NOT NULL,
    seq BIGSERIAL,
    update BYTEA NOT NULL,            -- opaque Yjs binary update
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (draft_id, logical_id, seq)
);
```

## Consequences

- All engagement/search/embed/export tables key on `logical_id`, never touching blobs/versions/FS (general ADR-0021).
- `search_index.expiry_date` lets search apply the render-time expiry rule (general ADR-0024).
- `y_updates` is written by the Node sidecar; Go reads it at serialize/publish time (general ADR-0027/0028).

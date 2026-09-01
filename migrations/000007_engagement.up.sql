-- 000007_engagement: browser-only engagement keyed by logical_id — comments,
-- reactions, reports (ADR-0021). None of this touches blobs, versions, or the
-- filesystem; it's a relational layer over the WS+HTMX surface.

CREATE TABLE comments (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    logical_id        UUID NOT NULL,
    author_principal  UUID NOT NULL REFERENCES principals(id) ON DELETE CASCADE,
    body              TEXT NOT NULL,
    parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at        TIMESTAMPTZ
);
CREATE INDEX comments_node ON comments (logical_id, created_at);

CREATE TABLE reactions (
    logical_id   UUID NOT NULL,
    principal_id UUID NOT NULL REFERENCES principals(id) ON DELETE CASCADE,
    kind         TEXT NOT NULL,
    PRIMARY KEY (logical_id, principal_id, kind)
);

CREATE TABLE reports (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    logical_id UUID NOT NULL,
    space_id   UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    reporter   UUID NOT NULL REFERENCES principals(id) ON DELETE CASCADE,
    reason     TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX reports_queue ON reports (space_id, status, created_at);

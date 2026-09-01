-- 000009_embeds: publishable, revocable embed slugs (ADR-0022). A slug is an
-- opaque public id; the transport signs it (HMAC) so tampered tokens are rejected
-- before a DB hit. Embeds read main only, live (tracks HEAD) or pinned to a seq.

CREATE TABLE embeds (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug       TEXT UNIQUE NOT NULL,
    logical_id UUID NOT NULL,
    space_id   UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    mode       TEXT NOT NULL DEFAULT 'live', -- 'live' | 'pinned'
    pinned_seq BIGINT,                        -- set when mode = 'pinned'
    revoked    BOOLEAN NOT NULL DEFAULT false,
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX embeds_node ON embeds (logical_id);

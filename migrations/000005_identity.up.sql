-- 000005_identity: principals (users + groups), group membership, and per-space
-- role grants (ADR-0014, ADR-0020). A user's effective role per space is the max
-- of their direct grant and any grant on a group they belong to; this is
-- flattened into JWT claims at login for O(1) hot-path checks.

CREATE TABLE principals (
    id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind   TEXT NOT NULL CHECK (kind IN ('user','group')),
    handle TEXT UNIQUE NOT NULL
);

CREATE TABLE group_members (
    group_id  UUID NOT NULL REFERENCES principals(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES principals(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, member_id)
);

CREATE TABLE space_grants (
    principal_id UUID NOT NULL REFERENCES principals(id) ON DELETE CASCADE,
    space_id     UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    role         TEXT NOT NULL CHECK (role IN ('viewer','contributor','editor','owner')),
    PRIMARY KEY (principal_id, space_id)
);

-- 000004_organizations (ADR-0034, S47): organizations + org membership.
-- Organizations are owners (kind=org) in the global slug namespace; their spaces
-- route to the org's shard just like personal owners. org_members tracks the three
-- org roles (owner/admin/member); base_perm controls what members get on every
-- org space by default (none/read/write, default read).

CREATE TABLE organizations (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    base_perm  TEXT NOT NULL DEFAULT 'read' CHECK (base_perm IN ('none', 'read', 'write')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE org_members (
    org_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
    role       TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, user_id)
);
CREATE INDEX org_members_user ON org_members (user_id);

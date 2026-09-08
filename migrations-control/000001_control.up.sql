-- 000001_control: the control-plane schema (ADR-0033). This lives in its OWN
-- database (KOINONIA_CONTROL_DATABASE_URL), separate from the tenant shards. It is
-- the global identity + tenancy registry and is never tenant-scoped / RLS'd.
--
-- S41 (tenancy tracer) needs just enough to resolve an owner slug/id → its shard's
-- DSN: shards, users, and the unified owners namespace. auth_identities, sessions,
-- organizations, org_members, and space_registry arrive in later slices (S45, S47).

CREATE TABLE shards (
    id         INT PRIMARY KEY,               -- 0 = the original database
    dsn        TEXT NOT NULL,                 -- connection string (uses the app role)
    writable   BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    handle     TEXT UNIQUE NOT NULL,          -- also the personal owner's slug
    email      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- owners unifies the global slug namespace over distinct entities (users now,
-- organizations in S47). slug is the first URL segment; shard_id routes to data.
CREATE TABLE owners (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind       TEXT NOT NULL CHECK (kind IN ('user','org')),
    ref_id     UUID NOT NULL,                 -- users.id (or organizations.id later)
    slug       TEXT UNIQUE NOT NULL,
    shard_id   INT NOT NULL REFERENCES shards(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX owners_shard ON owners (shard_id);

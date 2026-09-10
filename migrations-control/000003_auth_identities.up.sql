-- 000003_auth_identities: local email+password identity provider and server-side
-- revocable sessions (ADR-0032, S45). Lives in the control-plane DB
-- (koinonia_control) — never in tenant shards, never RLS-scoped.

-- auth_identities stores the argon2id password hash for a user's local account.
-- One row per user; a user can have at most one local identity (email/password).
-- Social (OIDC) identities arrive in S46 as a separate provider table.
CREATE TABLE auth_identities (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email         TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,  -- argon2id encoded: $argon2id$v=19$m=…,t=…,p=…$salt$hash
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- sessions is the server-side browser-session table. A login creates a row here;
-- the opaque token is set as an HttpOnly cookie. Each web request exchanges the
-- cookie for a short-lived (~15m) Ed25519 access token (ExchangeSession RPC).
-- Revocation (logout / kill-switch) sets revoked_at and is honoured instantly.
CREATE TABLE sessions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT UNIQUE NOT NULL,     -- 32 crypto-random bytes, base64url
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ              -- NULL = active
);
-- Hot lookup path: cookie-value → session row (active sessions only).
CREATE INDEX sessions_active ON sessions (token) WHERE revoked_at IS NULL;

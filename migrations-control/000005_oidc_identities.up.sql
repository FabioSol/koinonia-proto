-- oidc_identities links a social provider identity to a Koinonia user (S46).
-- (provider, subject) is the stable immutable key from the provider.
-- email may be NULL if the provider does not expose a public email.
CREATE TABLE oidc_identities (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider   TEXT        NOT NULL,
    subject    TEXT        NOT NULL,
    email      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider, subject)
);
CREATE INDEX oidc_identities_user ON oidc_identities (user_id);

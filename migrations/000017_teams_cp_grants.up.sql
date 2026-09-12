-- 000017_teams_cp_grants (ADR-0034, S49): flat team groups + direct CP-user space grants.
-- Teams are tenant-managed groups of CP user UUIDs granted a fixed role on a space.
-- cp_space_grants stores direct (outside-collaborator) grants using CP user UUIDs.
-- All three tables carry tenant_id + RLS matching the 000015/000016 pattern.
-- No FK to principals — CP user identity is owned by the control plane.

-- teams: one role-per-space team.
CREATE TABLE teams (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    space_id   UUID NOT NULL,
    name       TEXT NOT NULL,
    role       TEXT NOT NULL CHECK (role IN ('viewer','contributor','editor','owner')),
    tenant_id  UUID DEFAULT nullif(current_setting('app.tenant', true), '')::uuid,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX teams_tenant ON teams (tenant_id);
CREATE INDEX teams_space   ON teams (space_id);
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON teams
    USING      (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)
    WITH CHECK (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE, DELETE ON teams TO koinonia_app;

-- team_members: CP user UUIDs belonging to a team.
CREATE TABLE team_members (
    team_id    UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    cp_user_id UUID NOT NULL,
    tenant_id  UUID DEFAULT nullif(current_setting('app.tenant', true), '')::uuid,
    PRIMARY KEY (team_id, cp_user_id)
);
CREATE INDEX team_members_tenant ON team_members (tenant_id);
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON team_members
    USING      (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)
    WITH CHECK (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE, DELETE ON team_members TO koinonia_app;

-- cp_space_grants: direct space-role grants to individual CP users (outside collaborators).
CREATE TABLE cp_space_grants (
    cp_user_id UUID NOT NULL,
    space_id   UUID NOT NULL,
    role       TEXT NOT NULL CHECK (role IN ('viewer','contributor','editor','owner')),
    tenant_id  UUID DEFAULT nullif(current_setting('app.tenant', true), '')::uuid,
    PRIMARY KEY (cp_user_id, space_id)
);
CREATE INDEX cp_space_grants_tenant ON cp_space_grants (tenant_id);
CREATE INDEX cp_space_grants_space  ON cp_space_grants (space_id);
ALTER TABLE cp_space_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE cp_space_grants FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON cp_space_grants
    USING      (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid)
    WITH CHECK (tenant_id = nullif(current_setting('app.tenant', true), '')::uuid);
GRANT SELECT, INSERT, UPDATE, DELETE ON cp_space_grants TO koinonia_app;

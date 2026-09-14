-- 000020_transfer_space_fn: SECURITY DEFINER function for same-shard space transfer
-- (ADR-0033, S57). The function is owned by the superuser who runs migrations and
-- executes with that user's privileges, bypassing RLS. This lets koinonia_app (which
-- has FORCE ROW LEVEL SECURITY) atomically re-stamp tenant_id on all space-scoped
-- rows without requiring a separate superuser connection at runtime.
--
-- Tables NOT re-stamped here (ephemeral/collab state; cleaned by TTL sweep):
--   y_updates    — room key is "<draft_id>/<logical_id>", no direct space_id
--   coedit_locks — advisory; deleted when the room empties
--
-- Tables NOT re-stamped here (cross-space shared within a tenant):
--   principals, group_members — tenant-wide, not space-scoped
CREATE OR REPLACE FUNCTION restamp_space_tenant(
    p_space_id UUID,
    p_old_tid  UUID,
    p_new_tid  UUID
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    _logical_ids UUID[];
BEGIN
    -- Collect every logical_id touched by this space for tables keyed by logical_id.
    SELECT ARRAY(
        SELECT DISTINCT logical_id FROM nodes WHERE space_id = p_space_id
        UNION
        SELECT DISTINCT logical_id FROM node_history WHERE space_id = p_space_id
    ) INTO _logical_ids;

    -- Space-scoped tables (direct space_id column).
    UPDATE spaces SET tenant_id = p_new_tid
    WHERE id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE nodes SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE node_history SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE checkpoints SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE space_grants SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE teams SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE team_members SET tenant_id = p_new_tid
    WHERE team_id IN (SELECT id FROM teams WHERE space_id = p_space_id)
      AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE cp_space_grants SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE embeds SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE git_sync_jobs SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE export_jobs SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE reports SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE search_index SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE space_origins SET tenant_id = p_new_tid
    WHERE space_id = p_space_id AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    -- Logical-id-keyed tables (no space_id; join via nodes/node_history).
    UPDATE node_authors SET tenant_id = p_new_tid
    WHERE logical_id = ANY(_logical_ids)
      AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE comments SET tenant_id = p_new_tid
    WHERE logical_id = ANY(_logical_ids)
      AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    UPDATE reactions SET tenant_id = p_new_tid
    WHERE logical_id = ANY(_logical_ids)
      AND tenant_id IS NOT DISTINCT FROM p_old_tid;

    -- Blobs: content-addressed; insert rows under new tenant.
    -- Old rows become orphans cleaned by the blob-GC worker (S56).
    INSERT INTO blobs (hash, size_bytes, tenant_id)
    SELECT DISTINCT b.hash, b.size_bytes, p_new_tid
    FROM blobs b
    WHERE b.tenant_id IS NOT DISTINCT FROM p_old_tid
      AND b.hash IN (
          SELECT content_hash FROM nodes
          WHERE space_id = p_space_id AND content_hash IS NOT NULL
          UNION
          SELECT content_hash FROM node_history
          WHERE space_id = p_space_id AND content_hash IS NOT NULL
      )
    ON CONFLICT DO NOTHING;
END $$;

GRANT EXECUTE ON FUNCTION restamp_space_tenant(UUID, UUID, UUID) TO koinonia_app;

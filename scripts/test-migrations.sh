#!/usr/bin/env bash
# Verify the migrations apply cleanly on an empty Postgres 15+ and that the
# correctness carry-forwards hold. Uses an ephemeral Docker Postgres 16.
set -euo pipefail

MIG_DIR="$(cd "$(dirname "$0")/../migrations" && pwd)"
CNAME="koinonia-pg-test-$$"
cleanup() { docker rm -f "$CNAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "starting postgres:16 ($CNAME)…"
docker run -d --name "$CNAME" -e POSTGRES_PASSWORD=postgres postgres:16 >/dev/null

echo -n "waiting for readiness"
for _ in $(seq 1 60); do
  if docker exec "$CNAME" pg_isready -U postgres >/dev/null 2>&1; then echo " ok"; break; fi
  echo -n "."; sleep 1
done

psql_c() { docker exec -i "$CNAME" psql -v ON_ERROR_STOP=1 -U postgres -d postgres "$@"; }

echo "apply 000001_init.up.sql…"
psql_c < "$MIG_DIR/000001_init.up.sql"

echo "assert indexes present…"
psql_c -tAc "SELECT 1 FROM pg_indexes WHERE indexname='nodes_sibling_uniq'" | grep -q 1
psql_c -tAc "SELECT 1 FROM pg_indexes WHERE indexname='nodes_lookup'" | grep -q 1
echo "  ✓ nodes_sibling_uniq + nodes_lookup"

echo "apply 000003_node_history.up.sql…"
psql_c < "$MIG_DIR/000003_node_history.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='node_history'" | grep -q 1 \
  && echo "  ✓ node_history" || { echo "  ✗ node_history missing"; exit 1; }

echo "apply 000004_checkpoints.up.sql…"
psql_c < "$MIG_DIR/000004_checkpoints.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='checkpoints'" | grep -q 1 \
  && echo "  ✓ checkpoints" || { echo "  ✗ checkpoints missing"; exit 1; }

echo "apply 000005_identity.up.sql…"
psql_c < "$MIG_DIR/000005_identity.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='space_grants'" | grep -q 1 \
  && echo "  ✓ identity" || { echo "  ✗ identity missing"; exit 1; }

echo "apply 000006_node_authors.up.sql…"
psql_c < "$MIG_DIR/000006_node_authors.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='node_authors'" | grep -q 1 \
  && echo "  ✓ node_authors" || { echo "  ✗ node_authors missing"; exit 1; }

echo "apply 000007_engagement.up.sql…"
psql_c < "$MIG_DIR/000007_engagement.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='comments'" | grep -q 1 \
  && echo "  ✓ engagement" || { echo "  ✗ engagement missing"; exit 1; }

echo "apply 000008_search.up.sql…"
psql_c < "$MIG_DIR/000008_search.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='search_index'" | grep -q 1 \
  && echo "  ✓ search_index" || { echo "  ✗ search_index missing"; exit 1; }

echo "apply 000009_embeds.up.sql…"
psql_c < "$MIG_DIR/000009_embeds.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='embeds'" | grep -q 1 \
  && echo "  ✓ embeds" || { echo "  ✗ embeds missing"; exit 1; }

echo "apply 000010_history_provenance.up.sql…"
psql_c < "$MIG_DIR/000010_history_provenance.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.columns WHERE table_name='node_history' AND column_name='message'" | grep -q 1 \
  && echo "  ✓ history message column" || { echo "  ✗ history message column missing"; exit 1; }

echo "apply 000011_git_sync.up.sql…"
psql_c < "$MIG_DIR/000011_git_sync.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='git_sync_jobs'" | grep -q 1 \
  && echo "  ✓ git_sync_jobs" || { echo "  ✗ git_sync_jobs missing"; exit 1; }

echo "apply 000012_y_updates.up.sql…"
psql_c < "$MIG_DIR/000012_y_updates.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='y_updates'" | grep -q 1 \
  && echo "  ✓ y_updates" || { echo "  ✗ y_updates missing"; exit 1; }

echo "apply 000013_coedit_locks.up.sql…"
psql_c < "$MIG_DIR/000013_coedit_locks.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='coedit_locks'" | grep -q 1 \
  && echo "  ✓ coedit_locks" || { echo "  ✗ coedit_locks missing"; exit 1; }

echo "apply 000014_export_jobs.up.sql…"
psql_c < "$MIG_DIR/000014_export_jobs.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='export_jobs'" | grep -q 1 \
  && echo "  ✓ export_jobs" || { echo "  ✗ export_jobs missing"; exit 1; }

echo "apply 000015_tenancy_tracer.up.sql…"
psql_c < "$MIG_DIR/000015_tenancy_tracer.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.columns WHERE table_name='nodes' AND column_name='tenant_id'" | grep -q 1 \
  && echo "  ✓ nodes.tenant_id" || { echo "  ✗ nodes.tenant_id missing"; exit 1; }
psql_c -tAc "SELECT 1 FROM pg_policies WHERE tablename='nodes' AND policyname='tenant_isolation'" | grep -q 1 \
  && echo "  ✓ nodes RLS policy" || { echo "  ✗ nodes RLS policy missing"; exit 1; }
psql_c -tAc "SELECT 1 FROM pg_roles WHERE rolname='koinonia_app'" | grep -q 1 \
  && echo "  ✓ koinonia_app role" || { echo "  ✗ koinonia_app role missing"; exit 1; }

echo "apply 000016_tenancy_sweep.up.sql…"
psql_c < "$MIG_DIR/000016_tenancy_sweep.up.sql"
psql_c -tAc "SELECT count(*) FROM pg_policies WHERE policyname='tenant_isolation'" | grep -qx 18 \
  && echo "  ✓ RLS on 18 tenant tables" || { echo "  ✗ expected 18 tenant_isolation policies, got $(psql_c -tAc "SELECT count(*) FROM pg_policies WHERE policyname='tenant_isolation'")"; exit 1; }
psql_c -tAc "SELECT count(*) FROM information_schema.columns WHERE column_name='tenant_id' AND table_schema='public'" | grep -qx 18 \
  && echo "  ✓ tenant_id on 18 tables" || { echo "  ✗ expected 18 tenant_id columns"; exit 1; }

echo "assert duplicate MAIN siblings rejected (NULLS NOT DISTINCT)…"
psql_c -c "INSERT INTO spaces (id, slug) VALUES ('00000000-0000-0000-0000-0000000000aa','t');" >/dev/null
psql_c -c "INSERT INTO nodes (logical_id, space_id, name, kind) VALUES (gen_random_uuid(),'00000000-0000-0000-0000-0000000000aa','dup','article');" >/dev/null
if psql_c -c "INSERT INTO nodes (logical_id, space_id, name, kind) VALUES (gen_random_uuid(),'00000000-0000-0000-0000-0000000000aa','dup','article');" >/dev/null 2>&1; then
  echo "  ✗ duplicate MAIN sibling was ALLOWED — carry-forward broken"; exit 1
else
  echo "  ✓ duplicate MAIN sibling rejected"
fi

echo "apply 000002_dev_seed.up.sql…"
psql_c < "$MIG_DIR/000002_dev_seed.up.sql"
COUNT=$(psql_c -tAc "SELECT count(*) FROM nodes WHERE space_id='00000000-0000-0000-0000-000000000001'")
[ "$COUNT" = "3" ] && echo "  ✓ seed created 3 nodes" || { echo "  ✗ seed node count=$COUNT"; exit 1; }

echo "apply down migrations (round-trip)…"
psql_c < "$MIG_DIR/000002_dev_seed.down.sql"
psql_c < "$MIG_DIR/000016_tenancy_sweep.down.sql"
psql_c < "$MIG_DIR/000015_tenancy_tracer.down.sql"
psql_c < "$MIG_DIR/000014_export_jobs.down.sql"
psql_c < "$MIG_DIR/000013_coedit_locks.down.sql"
psql_c < "$MIG_DIR/000012_y_updates.down.sql"
psql_c < "$MIG_DIR/000011_git_sync.down.sql"
psql_c < "$MIG_DIR/000010_history_provenance.down.sql"
psql_c < "$MIG_DIR/000009_embeds.down.sql"
psql_c < "$MIG_DIR/000008_search.down.sql"
psql_c < "$MIG_DIR/000007_engagement.down.sql"
psql_c < "$MIG_DIR/000006_node_authors.down.sql"
psql_c < "$MIG_DIR/000005_identity.down.sql"
psql_c < "$MIG_DIR/000004_checkpoints.down.sql"
psql_c < "$MIG_DIR/000003_node_history.down.sql"
psql_c < "$MIG_DIR/000001_init.down.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='nodes'" | grep -q 1 && { echo "  ✗ nodes table still present after down"; exit 1; } || echo "  ✓ schema dropped cleanly"

# Control-plane schema (separate database in production; applied here to the now-empty db).
CTL_DIR="$(cd "$MIG_DIR/../migrations-control" && pwd)"
echo "apply control-plane 000001_control.up.sql…"
psql_c < "$CTL_DIR/000001_control.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='owners'" | grep -q 1 \
  && echo "  ✓ control owners/shards/users" || { echo "  ✗ control schema missing"; exit 1; }

echo "apply control-plane 000002_space_registry.up.sql…"
psql_c < "$CTL_DIR/000002_space_registry.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='space_registry'" | grep -q 1 \
  && echo "  ✓ control space_registry" || { echo "  ✗ control space_registry missing"; exit 1; }

echo "apply control-plane 000003_auth_identities.up.sql…"
psql_c < "$CTL_DIR/000003_auth_identities.up.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='auth_identities'" | grep -q 1 \
  && echo "  ✓ auth_identities" || { echo "  ✗ auth_identities missing"; exit 1; }
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='sessions'" | grep -q 1 \
  && echo "  ✓ sessions" || { echo "  ✗ sessions missing"; exit 1; }
psql_c -tAc "SELECT 1 FROM pg_indexes WHERE indexname='sessions_active'" | grep -q 1 \
  && echo "  ✓ sessions_active index" || { echo "  ✗ sessions_active index missing"; exit 1; }

echo "apply control-plane down migrations (round-trip)…"
psql_c < "$CTL_DIR/000003_auth_identities.down.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='sessions'" | grep -q 1 \
  && { echo "  ✗ sessions still present after down"; exit 1; } || echo "  ✓ 000003 down clean"
psql_c < "$CTL_DIR/000002_space_registry.down.sql"
psql_c < "$CTL_DIR/000001_control.down.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='owners'" | grep -q 1 \
  && { echo "  ✗ control owners still present after down"; exit 1; } || echo "  ✓ control schema dropped cleanly"

echo "ALL MIGRATION CHECKS PASSED"

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
psql_c < "$MIG_DIR/000006_node_authors.down.sql"
psql_c < "$MIG_DIR/000005_identity.down.sql"
psql_c < "$MIG_DIR/000004_checkpoints.down.sql"
psql_c < "$MIG_DIR/000003_node_history.down.sql"
psql_c < "$MIG_DIR/000001_init.down.sql"
psql_c -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='nodes'" | grep -q 1 && { echo "  ✗ nodes table still present after down"; exit 1; } || echo "  ✓ schema dropped cleanly"

echo "ALL MIGRATION CHECKS PASSED"

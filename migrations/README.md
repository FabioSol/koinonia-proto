# Migrations

PostgreSQL schema for Koinonia, as ordered SQL files. Naming follows the
[golang-migrate](https://github.com/golang-migrate/migrate) convention
(`NNNNNN_name.up.sql` / `.down.sql`) so it works with `migrate`, or with plain
`psql` applied in order.

**Requires PostgreSQL 15+** (`NULLS NOT DISTINCT`).

| Migration | Purpose |
|---|---|
| `000001_init` | Core namespace tables: `spaces`, `nodes`, `blobs` (+ sibling-uniqueness and lookup indexes) |
| `000002_dev_seed` | **Dev/demo only** — one space with a small tree. Skip in production. |

## Apply

With `migrate`:

```sh
migrate -path . -database "$DATABASE_URL" up          # all, incl. dev seed
migrate -path . -database "$DATABASE_URL" up 1         # schema only (no seed)
```

With `psql` (schema only):

```sh
psql "$DATABASE_URL" -f 000001_init.up.sql
```

## Verify

`scripts/test-migrations.sh` spins up an ephemeral Docker Postgres 16, applies
the migrations, and asserts the correctness carry-forwards (duplicate MAIN
siblings rejected; lookup index present; up/down round-trip).

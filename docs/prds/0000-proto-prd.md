# PRD — koinonia-proto (schema + contracts)

## Problem Statement

Every Koinonia component needs to agree, exactly, on the shape of the data (the node tree, versions, history, drafts, frontmatter, principals, engagement, search) and on the wire calls between the FUSE client and the backend. Without one authoritative, versioned definition, the server, FUSE client, and web diverge and break silently.

## Solution

A single shared module holding (1) the PostgreSQL schema + migrations and (2) the gRPC/protobuf service and message definitions, generated into Go for import by consumers. It is the "brain's" data contract and the client-server API contract in one place.

## User Stories

1. As a backend developer, I want the authoritative DDL and migrations in one repo, so that schema changes are reviewed centrally.
2. As a FUSE developer, I want typed gRPC stubs for Lookup/ReadDir/Getattr/CAS/Presign/Subscribe, so that I call the backend without hand-rolling messages.
3. As a reviewer, I want proto changes to be visible as API changes, so that breaking changes are caught.
4. As an operator, I want ordered, idempotent migrations, so that environments converge deterministically.
5. As a developer, I want the overlay/ordering/uniqueness rules encoded in constraints and indexes, so that correctness carry-forwards can't be forgotten.

## Implementation Decisions

- **Modules built:** the `.proto` definitions + generated Go (`pkg/`); the SQL migration set; a small schema-doc.
- **Core tables:** `spaces`, `nodes`, `node_history`, `blobs`, `principals`, `group_members`, `space_grants`, `node_authors`, `comments`, `reactions`, `reports`, `embeds`, `checkpoints`, `search_index`, `export_jobs`, `y_updates`. See `docs/adrs/0001` and `0003` for concrete DDL.
- **gRPC service** `Koinonia`: unary `Lookup`, `ReadDir`, `Getattr`, `BlobExists`, `PresignGet`, `PresignPut`, `Commit` (CAS), `Publish`, plus server-streaming `Subscribe`. See `docs/adrs/0002`.
- **Encoded correctness:** `draft_id DESC NULLS LAST` ordering standardized; `UNIQUE(parent_id, name, draft_id) NULLS NOT DISTINCT`; `is_deleted` tombstones; `node_history` versions structural columns; global `seq BIGSERIAL`.
- **API contract:** the `Commit` message carries `{logical_id, expected_version, content_hash, frontmatter}`; conflict is a typed error mapped to `ESTALE`/`EINVAL`/`EACCES`/`EAGAIN` by the FUSE client.

## Testing Decisions

- Test **migrations apply cleanly forward** on an empty DB and that constraints reject the known-bad cases (duplicate main siblings; draft-shadowing order).
- Golden tests on **overlay resolution SQL** (draft wins; fall-through to main; tombstone → absent) as pure query tests against fixtures.
- Proto backward-compatibility checks in CI (buf lint/breaking).

## Out of Scope

- Business logic (lives in `koinonia-server`); this repo is contracts + schema only.
- pgvector columns at launch (leave room in `search_index` design — general ADR-0023).

## Further Notes

Keep `<ORG>` module path consistent across repos; strip `replace` directives before tagging releases (general ADR-0001).

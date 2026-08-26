# koinonia-proto

Shared source-of-truth contracts for Koinonia: the PostgreSQL schema + migrations and the gRPC/protobuf service definitions that every other repo depends on.

- **Consumers** (`koinonia-server`, `koinonia-fuse`) import this module by its GitHub path via `replace` directives during local dev (see `docs/adrs/` and general [ADR-0001](../docs/adrs/0001-repository-topology.md)).
- **Contents:** `.proto` service/message definitions (generated Go into `pkg/`), SQL migrations, and the canonical schema DDL.
- **Contract discipline:** treat everything here as a versioned API; breaking changes ripple to server + fuse and require coordinated PRs.

## Docs

- PRD: [`docs/prds/0000-proto-prd.md`](docs/prds/0000-proto-prd.md)
- ADRs: schema for nodes + history, the gRPC service contract, and the CMS/collab tables — see `docs/adrs/`.

## Relevant general ADRs

0007 (tree model), 0008 (drafts), 0010 (deletes), 0012 (transport), 0016 (time travel), 0018 (sections), 0020 (principals), 0023 (search).

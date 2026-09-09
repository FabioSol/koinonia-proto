-- 000002_space_registry (ADR-0033, S43): maps an owner/space path to the space's
-- id + shard, so `/{owner}/{space}` resolves with one control-plane lookup (no
-- fan-out across shards). Populated when a space is created/imported/backfilled.

CREATE TABLE space_registry (
    owner_id   UUID NOT NULL REFERENCES owners(id) ON DELETE CASCADE,
    space_slug TEXT NOT NULL,
    space_id   UUID NOT NULL,
    shard_id   INT  NOT NULL REFERENCES shards(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_id, space_slug)
);

-- 000013_coedit_locks: advisory locks held while a Yjs co-editing room is live on
-- a draft node (ADR-0028). The collab sidecar inserts a row on room open and
-- deletes it when the room empties; koinonia-server's Commit refuses a draft write
-- to a locked node (→ UNAVAILABLE → FUSE EAGAIN). Reads are never blocked. Rows are
-- advisory + ephemeral (a crashed sidecar leaves a stale row; cleanup is a TTL/sweep
-- concern, deferred). logical_id/draft_id are TEXT so the Node sidecar writes them
-- without a uuid cast.

CREATE TABLE coedit_locks (
    logical_id  TEXT NOT NULL,
    draft_id    TEXT NOT NULL,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (logical_id, draft_id)
);

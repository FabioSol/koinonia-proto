-- 000012_y_updates: durable Yjs document state for the koinonia-collab sidecar
-- (ADR-0027, collab ADR-0001). One snapshot row per room; the room key is
-- "<draft_id>/<logical_id>" (draft nodes only). Owned by koinonia-collab; Go never
-- reads it (Go serializes drafts to blobs at publish, not from here).

CREATE TABLE y_updates (
    room       TEXT PRIMARY KEY,   -- "<draft_id>/<logical_id>"
    doc        BYTEA NOT NULL,     -- encoded Yjs document state (Y.encodeStateAsUpdate)
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

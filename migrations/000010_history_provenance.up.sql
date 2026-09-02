-- 000010_history_provenance: carry a commit message on history rows so git
-- import can replay author/message/timestamp (ADR-0029/0030). `actor`/`updated_by`
-- already hold the author; `created_at` is set to the source commit time on
-- import. Native writes leave `message` NULL.

ALTER TABLE node_history ADD COLUMN message TEXT;

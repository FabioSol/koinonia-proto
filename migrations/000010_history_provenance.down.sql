-- 000010_history_provenance (down)
ALTER TABLE node_history DROP COLUMN IF EXISTS message;

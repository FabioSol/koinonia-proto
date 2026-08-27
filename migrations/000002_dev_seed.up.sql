-- 000002_dev_seed: demo data for LOCAL DEVELOPMENT ONLY. Safe to skip in prod
-- (apply migrations only up to 000001 for a clean environment).
-- One space with a small tree: space root -> section 'guides' -> article 'intro.md'.

INSERT INTO spaces (id, slug, settings) VALUES
  ('00000000-0000-0000-0000-000000000001', 'demo', '{}');

INSERT INTO nodes (id, logical_id, space_id, parent_id, name, kind, content_hash, frontmatter) VALUES
  ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001', NULL, 'demo', 'space', NULL, '{}'),
  ('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001', 'guides', 'section', NULL, '{"title":"Guides"}'),
  ('30000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000001', 'intro.md', 'article', NULL, '{"title":"Intro"}');

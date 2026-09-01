-- 000008_search: a Postgres-FTS projection maintained by the async indexer
-- (ADR-0023). Only main-branch (published) content is indexed; the indexer is the
-- one sanctioned server-side blob read. tsv drives ranking; fm_facets drives facet
-- filtering; expiry_date drives hide_expired (ADR-0024).

CREATE TABLE search_index (
    logical_id   UUID PRIMARY KEY,
    space_id     UUID NOT NULL,
    content_hash TEXT,
    tsv          TSVECTOR,
    plaintext    TEXT,
    fm_facets    JSONB NOT NULL DEFAULT '{}',
    expiry_date  TIMESTAMPTZ,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX search_tsv    ON search_index USING GIN (tsv);
CREATE INDEX search_facets ON search_index USING GIN (fm_facets);
CREATE INDEX search_space  ON search_index (space_id);

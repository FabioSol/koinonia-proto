-- 000006_node_authors: authorship as pure attribution (byline + search facet),
-- decoupled from edit rights, which come from space grants (ADR-0020). Keyed by
-- logical_id (no FK: logical_id is not unique across versions/drafts).

CREATE TABLE node_authors (
    logical_id   UUID NOT NULL,
    principal_id UUID NOT NULL REFERENCES principals(id) ON DELETE CASCADE,
    PRIMARY KEY (logical_id, principal_id)
);

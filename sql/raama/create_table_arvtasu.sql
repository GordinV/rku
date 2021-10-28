-- Table: docs.arvtasu

-- DROP TABLE IF EXISTS docs.arvtasu;

CREATE TABLE IF NOT EXISTS docs.arvtasu
(
    id serial,
    rekvid integer NOT NULL,
    doc_arv_id integer NOT NULL,
    doc_tasu_id integer,
    kpv date NOT NULL DEFAULT ('now'::text)::date,
    summa numeric(14,4) NOT NULL DEFAULT 0,
    dok text,
    pankkassa smallint NOT NULL DEFAULT 0,
    muud text,
    properties jsonb,
    status integer DEFAULT 0,
    CONSTRAINT arvtasu_pkey PRIMARY KEY (id)
)   TABLESPACE pg_default;

GRANT UPDATE, DELETE, INSERT, SELECT ON TABLE docs.arvtasu TO db;

GRANT ALL ON SEQUENCE docs.arvtasu_id_seq TO db;


-- Index: arvtasu_doc_arv_id

-- DROP INDEX IF EXISTS docs.arvtasu_doc_arv_id;

CREATE INDEX IF NOT EXISTS arvtasu_doc_arv_id
    ON docs.arvtasu USING btree
        (doc_arv_id ASC NULLS LAST);
-- Index: arvtasu_doc_tasu_id

-- DROP INDEX IF EXISTS docs.arvtasu_doc_tasu_id;

CREATE INDEX IF NOT EXISTS arvtasu_doc_tasu_id
    ON docs.arvtasu USING btree
        (doc_tasu_id ASC NULLS LAST);
-- Index: arvtasu_kpv

-- DROP INDEX IF EXISTS docs.arvtasu_kpv;

CREATE INDEX IF NOT EXISTS arvtasu_kpv
    ON docs.arvtasu USING btree
        (kpv ASC NULLS LAST);
-- Index: idx_arvtasu_tasu

-- DROP INDEX IF EXISTS docs.idx_arvtasu_tasu;

CREATE UNIQUE INDEX IF NOT EXISTS idx_arvtasu_tasu
    ON docs.arvtasu USING btree
        (doc_tasu_id ASC NULLS LAST, doc_arv_id ASC NULLS LAST)
    WHERE status <> 3;


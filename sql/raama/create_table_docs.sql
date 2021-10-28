DROP TABLE IF EXISTS docs.doc;

CREATE TABLE docs.doc (
    id          SERIAL,
    rekvid INTEGER,
    docs_ids INTEGER[],
    created     TIMESTAMP DEFAULT now(),
    lastupdate  TIMESTAMP DEFAULT now(),
    doc_type_id INTEGER,
    bpm         JSONB,
    history     JSONB,
    status      INTEGER   DEFAULT 0,
    CONSTRAINT docs_pkey PRIMARY KEY (id)
)
    WITH (
        OIDS= FALSE
    );

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.doc TO db;


COMMENT ON COLUMN docs.doc.doc_type_id IS 'тип документа, из таблицы library.kood';
COMMENT ON COLUMN docs.doc.bpm IS 'бизнес процесс';
COMMENT ON COLUMN docs.doc.docs_ids IS 'seotud dokumendide id';

CREATE INDEX idx_doc_status ON docs.doc USING btree (status);

drop INDEX if EXISTS  idx_doc_typ_id;
CREATE INDEX idx_doc_typ_id ON docs.doc USING btree (doc_type_id) where status <> 3;

/*

insert into docs.doc (doc_type_id) values ((select id from library where library = 'DOK' AND kood = 'ARV'))
select * from docs.doc
*/

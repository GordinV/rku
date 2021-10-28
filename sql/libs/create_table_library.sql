DROP TABLE IF EXISTS libs.library;

CREATE TABLE libs.library (
    id         SERIAL,
    rekvid     INTEGER                     NOT NULL,
    kood       CHARACTER(20)               NOT NULL DEFAULT '',
    nimetus    CHARACTER(254)              NOT NULL DEFAULT '',
    library    CHARACTER(20)               NOT NULL DEFAULT '',
    muud       TEXT,
    properties JSONB,
    timestamp  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT LOCALTIMESTAMP,
    CONSTRAINT library_pkey PRIMARY KEY (id),
    status     INTEGER                     NOT NULL DEFAULT 1,
    ajalugu    JSONB
)
    WITH (
        OIDS= FALSE
    );

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE libs.library TO db;

-- Index: libs.library_kood

-- DROP INDEX libs.library_kood;

CREATE INDEX library_kood
    ON libs.library
        USING btree
        (kood COLLATE pg_catalog."default")
    WHERE library.status <> 3;

-- Index: libs.library_library

-- DROP INDEX libs.library_library;

CREATE INDEX library_library
    ON libs.library
        USING btree
        (library COLLATE pg_catalog."default")
    WHERE library.status <> 3;

-- Index: libs.library_rekvid

-- DROP INDEX libs.library_rekvid;

CREATE INDEX library_rekvid
    ON libs.library
        USING btree
        (rekvid);

ALTER TABLE libs.library
    CLUSTER ON library_rekvid;

DROP INDEX IF EXISTS library_docs_modules;
CREATE INDEX library_docs_modules
    ON libs.library ((properties :: JSONB ->> 'module'))
    WHERE library = 'DOK';


ALTER TABLE libs.library
    CLUSTER ON library_rekvid;

CREATE INDEX library_idx_cluster_library
    ON libs.library USING btree
        (library ASC NULLS LAST)
    INCLUDE (library)
    TABLESPACE pg_default;

ALTER TABLE libs.library
    CLUSTER ON library_idx_cluster_library;


DROP TABLE IF EXISTS docs.rekl;

CREATE TABLE docs.rekl (
    id         SERIAL,
    rekvid     INTEGER                     NOT NULL,
    parentid   INTEGER,
    asutusid   INTEGER,
    alg_kpv    DATE,
    lopp_kpv   DATE,
    nimetus    TEXT,
    link       TEXT,
    muud       TEXT,
    properties JSONB,
    timestamp  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT LOCALTIMESTAMP,
    status     INTEGER                     NOT NULL DEFAULT 1,
    ajalugu    JSONB,
    CONSTRAINT rekl_pkey PRIMARY KEY (id)
)
    WITH (
        OIDS= FALSE
    );

ALTER TABLE docs.rekl add COLUMN last_shown TIMESTAMP WITHOUT TIME ZONE;

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.rekl TO db;

-- Index: libs.library_kood

-- DROP INDEX libs.library_kood;

CREATE INDEX rekl_rekvid
    ON docs.rekl
        USING btree
        (rekvid)
    WHERE rekl.status <> 3;

CREATE INDEX rekl_asutusid
    ON docs.rekl
        USING btree
        (asutusid)
    WHERE rekl.status <> 3;



GRANT ALL ON SEQUENCE docs.rekl_id_seq TO db;

ALTER TABLE docs.rekl
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.doc (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

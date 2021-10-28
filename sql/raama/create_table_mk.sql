-- Table: docs.mk

DROP TABLE IF EXISTS docs.mk;

CREATE TABLE docs.mk (
    id         SERIAL,
    rekvid     INTEGER               NOT NULL,
    journalid  INTEGER               NOT NULL DEFAULT 0,
    aaid       INTEGER               NOT NULL DEFAULT 0,
    doklausid  INTEGER               NOT NULL DEFAULT 0,
    kpv        DATE                  NOT NULL DEFAULT current_date::DATE,
    maksepaev  DATE                  NOT NULL DEFAULT current_date::DATE,
    "number"   CHARACTER VARYING(20) NOT NULL DEFAULT '',
    selg       TEXT                  NOT NULL DEFAULT '',
    viitenr    CHARACTER VARYING(20) NOT NULL DEFAULT '',
    opt        INTEGER               NOT NULL DEFAULT 1,
    muud       TEXT,
    arvid      INTEGER               NOT NULL DEFAULT 0,
    doktyyp    INTEGER               NOT NULL DEFAULT 0,
    dokid      INTEGER               NOT NULL DEFAULT 0,
    parentId   INTEGER,
    jaak       NUMERIC(14, 2)        NOT NULL DEFAULT 0,
    properties JSONB                 NULL,
        CONSTRAINT mk_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.mk TO db;

DROP INDEX IF EXISTS mk_parentid_idx;
CREATE INDEX IF NOT EXISTS mk_parentid_idx ON docs.mk (parentid);

DROP INDEX IF EXISTS mk_maksepaev_idx;
CREATE INDEX IF NOT EXISTS mk_maksepaev_idx ON docs.mk (maksepaev);

DROP INDEX IF EXISTS mk_rekvid_idx;
CREATE INDEX IF NOT EXISTS mk_rekvid_idx ON docs.mk (rekvid);

DROP INDEX IF EXISTS mk_opt_idx;
CREATE INDEX IF NOT EXISTS mk_opt_idx ON docs.mk (opt);

ALTER TABLE docs.mk
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.doc (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

GRANT ALL ON SEQUENCE docs.mk_id_seq TO db;


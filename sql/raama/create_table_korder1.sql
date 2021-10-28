-- Table: public.korder1

DROP TABLE IF EXISTS docs.korder1;

CREATE TABLE docs.korder1 (
    id        SERIAL,
    parentid  INTEGER        NOT NULL,
    rekvid    INTEGER        NOT NULL,
    userid    INTEGER        NOT NULL,
    journalid INTEGER,
    kassaid   INTEGER        NOT NULL,
    tyyp      INTEGER        NOT NULL DEFAULT 1,
    doklausid INTEGER,
    "number"  TEXT           NOT NULL,
    kpv       DATE           NOT NULL DEFAULT ('now'::TEXT)::DATE,
    asutusid  INTEGER        NOT NULL,
    nimi      TEXT           NOT NULL,
    aadress   TEXT,
    dokument  TEXT,
    alus      TEXT,
    summa     NUMERIC(12, 4) NOT NULL DEFAULT 0,
    muud      TEXT,
    arvid     INTEGER,
    doktyyp   INTEGER,
    dokid     INTEGER,
    CONSTRAINT korder1_pkey PRIMARY KEY (id)

);

GRANT SELECT, UPDATE, INSERT ON TABLE docs.korder1 TO db;


DROP INDEX IF EXISTS docs.korder1_rekv_idx;

CREATE INDEX korder1_rekv_idx
    ON docs.korder1
        USING btree
        (rekvid);

DROP INDEX IF EXISTS docs.korder1_kpv_idx;

CREATE INDEX korder1_kpv_idx
    ON docs.korder1
        USING btree
        (kpv);

DROP INDEX IF EXISTS docs.korder1_number_idx;

CREATE INDEX korder1_number_idx
    ON docs.korder1
        USING btree
        (number);

DROP INDEX IF EXISTS docs.korder1_parent_idx;

CREATE INDEX korder1_parent_idx
    ON docs.korder1
        USING btree
        (parentid);


CREATE INDEX korder1_asuitus_idx
    ON docs.korder1
        USING btree
        (asutusid);


ALTER TABLE docs.korder1
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.doc (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

GRANT ALL ON SEQUENCE docs.korder1_id_seq TO db;


/*
select * from docs.korder1

update docs.korder1 set muud = 'test' where id = 22

*/
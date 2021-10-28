-- Table: public.arv

DROP TABLE IF EXISTS docs.arv;

CREATE TABLE docs.arv (
    id        SERIAL,
    rekvid    INTEGER        NOT NULL,
    userid    INTEGER        NOT NULL,
    journalid INTEGER        NOT NULL DEFAULT 0,
    doklausid INTEGER        NOT NULL DEFAULT 0,
    liik      SMALLINT       NOT NULL DEFAULT 0,
    operid    INTEGER        NOT NULL DEFAULT 0,
    "number"  CHARACTER(20)  NOT NULL,
    kpv       DATE           NOT NULL DEFAULT ('now' :: TEXT) :: DATE,
    asutusid  INTEGER        NOT NULL DEFAULT 0,
    arvid     INTEGER        NOT NULL DEFAULT 0,
    lisa      CHARACTER(120) NOT NULL,
    tahtaeg   DATE,
    kbmta     NUMERIC(12, 4) NOT NULL DEFAULT 0,
    kbm       NUMERIC(12, 4) NOT NULL DEFAULT 0,
    summa     NUMERIC(12, 4) NOT NULL DEFAULT 0,
    tasud     DATE,
    tasudok   CHARACTER(254),
    muud      TEXT,
    jaak      NUMERIC(12, 4) NOT NULL DEFAULT 0,
    objektid  INTEGER        NOT NULL DEFAULT 0,
    objekt    CHARACTER VARYING(20),
    parentId  INTEGER,
    properties JSONB,
    CONSTRAINT arv_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.arv TO db;


CREATE INDEX idx_arv_parentid
    ON docs.arv USING BTREE (parentid);
CREATE INDEX idx_arv_rekvid
    ON docs.arv USING BTREE (rekvid);
CREATE INDEX idx_arv_asutusid
    ON docs.arv USING BTREE (asutusid);

DROP INDEX IF EXISTS idx_arv_kpv;
CREATE INDEX IF NOT EXISTS idx_arv_kpv ON docs.arv (kpv);


DROP RULE IF EXISTS arv_insert_2020 ON docs.arv;
CREATE RULE arv_insert_2020 AS ON INSERT TO docs.arv
    WHERE kpv <= '2020-12-31'
    DO INSTEAD NOTHING;


GRANT ALL ON SEQUENCE docs.arv_id_seq TO db;

ALTER TABLE docs.arv
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.doc (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

DROP TABLE IF EXISTS docs.arv1;

CREATE TABLE docs.arv1 (
    id         SERIAL,
    parentid   INTEGER        NOT NULL,
    nomid      INTEGER        NOT NULL,
    kogus      NUMERIC(18, 3) NOT NULL DEFAULT 0,
    hind       NUMERIC(12, 4) NOT NULL DEFAULT 0,
    soodus     SMALLINT       NOT NULL DEFAULT 0,
    kbm        NUMERIC(12, 4) NOT NULL DEFAULT 0,
    summa      NUMERIC(12, 4) NOT NULL DEFAULT 0,
    muud       TEXT,
    konto      CHARACTER VARYING(20),
    kbmta      NUMERIC(12, 4) NOT NULL DEFAULT 0,
    isikid     INTEGER        NOT NULL DEFAULT 0,
    tunnus     CHARACTER VARYING(20),
    proj       CHARACTER VARYING(20),
    properties JSONB,
    CONSTRAINT arv1_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.arv1 TO db;

GRANT ALL ON SEQUENCE docs.arv1_id_seq TO db;


-- Index: public.arv1_nomid

-- DROP INDEX public.arv1_nomid;

CREATE INDEX arv1_nomid
    ON docs.arv1
        USING btree
        (nomid);


CREATE INDEX arv1_parentid
    ON docs.arv1
        USING btree
        (parentid);


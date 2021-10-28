DROP TABLE IF EXISTS docs.korder2;

CREATE TABLE docs.korder2 (
    id       SERIAL,
    parentid INTEGER        NOT NULL,
    nomid    INTEGER        NOT NULL,
    nimetus  TEXT           NOT NULL,
    summa    NUMERIC(12, 4) NOT NULL DEFAULT 0,
    konto    CHARACTER VARYING(20),
    tunnus   CHARACTER VARYING(20),
    proj     CHARACTER VARYING(20),
    muud     TEXT,
    CONSTRAINT korder2_pkey PRIMARY KEY (id)
);


GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.korder2 TO db;

DROP INDEX IF EXISTS docs.korder2_parentid_idx;

CREATE INDEX korder2_parentid_idx
    ON docs.korder2
        USING btree
        (parentid);

DROP INDEX IF EXISTS docs.korder2_nomid_idx;

CREATE INDEX korder2_nomid_idx
    ON docs.korder2
        USING btree
        (nomid);


ALTER TABLE docs.korder2
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.korder1 (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

GRANT ALL ON SEQUENCE docs.korder2_id_seq TO db;


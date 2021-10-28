drop TABLE if exists docs.moodu2 cascade;

CREATE TABLE docs.moodu2
(
    id serial NOT NULL,
    parentid integer NOT NULL,
    nomid integer NOT NULL,
    kogus numeric(12,3) NOT NULL DEFAULT 0,
    muud text,
    properties jsonb,
    CONSTRAINT moodu2_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.moodu2 TO db;

DROP INDEX if exists moodu2_nomid;

CREATE INDEX moodu2_nomid
    ON docs.moodu2
        USING btree
        (nomid);

DROP INDEX if exists moodu2_parentid;

CREATE INDEX moodu2_parentid
    ON docs.moodu2
        USING btree
        (parentid);


ALTER TABLE docs.moodu2
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.moodu1 (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

GRANT ALL ON SEQUENCE docs.moodu2_id_seq TO db;

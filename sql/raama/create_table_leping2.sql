drop TABLE if exists docs.leping2 cascade;

CREATE TABLE docs.leping2
(
  id serial NOT NULL,
  parentid integer NOT NULL,
  nomid integer NOT NULL,
  kogus numeric(12,3) NOT NULL DEFAULT 0,
  hind numeric(12,4) NOT NULL DEFAULT 0,
  summa numeric(12,4) NOT NULL DEFAULT 0,
  status smallint NOT NULL DEFAULT 1,
  muud text,
  formula text,
  kbm integer NOT NULL DEFAULT 1,
  CONSTRAINT leping2_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.leping2 TO db;
GRANT ALL ON SEQUENCE docs.leping2_id_seq TO db;


DROP INDEX if exists leping2_nomid;

CREATE INDEX leping2_nomid
  ON docs.leping2
  USING btree
  (nomid);

DROP INDEX if exists leping2_parentid;

CREATE INDEX leping2_parentid
  ON docs.leping2
  USING btree
  (parentid);


ALTER TABLE docs.leping2
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.leping1 (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

GRANT ALL ON SEQUENCE docs.leping2_id_seq TO db;

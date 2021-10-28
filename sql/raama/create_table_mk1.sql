-- Table: docs.mk1

DROP TABLE if exists docs.mk1 ;

CREATE TABLE docs.mk1
(
  id serial,
  parentid integer NOT NULL,
  asutusid integer NOT NULL,
  nomid integer NOT NULL,
  summa numeric(12,4) NOT NULL DEFAULT 0,
  aa character varying(20) NOT NULL,
  pank character varying(3),
  journalid integer null,
  konto character varying(20),
  tp character varying(20),
  tunnus character varying(20),
  proj character varying(20),
  CONSTRAINT mk1_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.mk1 TO db;

create index idx_mk1_parentid on docs.mk1 USING BTREE (parentid);
create index idx_mk1_asutusid on docs.mk1 USING BTREE (asutusid);
create index idx_mk1_nomidid on docs.mk1 USING BTREE (nomid);


ALTER TABLE docs.mk1
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid)
        REFERENCES docs.mk (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE;

GRANT ALL ON SEQUENCE docs.mk1_id_seq TO db;



DROP TABLE if exists docs.journal1;

CREATE TABLE docs.journal1
(
  id serial,
  parentid integer NOT NULL,
  summa numeric(16,4) NOT NULL DEFAULT 0,
  dokument text,
  muud text,
  kood1 character varying(20) ,
  kood2 character varying(20),
  kood3 character varying(20),
  kood4 character varying(20),
  kood5 character varying(20),
  deebet character varying(20),
  lisa_k character varying(20),
  kreedit character varying(20),
  lisa_d character varying(20),
  tunnus character varying(20),
  proj character varying(20),
  CONSTRAINT journal1_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.journal1 TO db;

GRANT ALL ON SEQUENCE docs.journal1_id_seq TO db;



 DROP INDEX if exists docs.journal1_dbkr_idx;

CREATE INDEX journal1_dbkr_idx
  ON docs.journal1
  USING btree
  (deebet COLLATE pg_catalog."default", kreedit COLLATE pg_catalog."default");


DROP INDEX if exists docs.journal1_eelarve_idx;

CREATE INDEX journal1_eelarve_idx
  ON docs.journal1
  USING btree
  (kood1 COLLATE pg_catalog."default", kood2 COLLATE pg_catalog."default", kood3 COLLATE pg_catalog."default", kood5 COLLATE pg_catalog."default", lisa_d COLLATE pg_catalog."default", lisa_k COLLATE pg_catalog."default");


DROP INDEX if exists docs.journal1_tunnus_idx;

CREATE INDEX journal1_tunnus_idx
  ON docs.journal1
  USING btree
  (tunnus COLLATE pg_catalog."default");


DROP INDEX if exists docs.journal_parentid_idx;

CREATE INDEX journal_parentid_idx
  ON docs.journal1
  USING btree
  (parentid);

ALTER TABLE docs.journal1 CLUSTER ON journal_parentid_idx;

create table IF NOT EXISTS docs.journal1_2021 (aasta integer) INHERITS  (docs.journal1);

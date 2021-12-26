
DROP TABLE if exists docs.journalid;

CREATE TABLE docs.journalid
(
  id serial,
  rekvid integer NOT NULL,
  journalid integer NOT NULL,
  "number" integer NOT NULL DEFAULT 0,
  aasta integer NOT NULL DEFAULT cast(extract(year from current_date) as int),
  CONSTRAINT journalid_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.journalid TO db;

GRANT ALL ON SEQUENCE docs.journalid_id_seq TO db;


DROP INDEX if exists docs.journalid_rekvid_idx;

CREATE INDEX journalid_rekvid_idx
  ON docs.journalid
  USING btree
  (rekvid);


 DROP INDEX if exists docs.journalid_journalid_idx;

CREATE INDEX journalid_journalid_idx
  ON docs.journalid
  USING btree
  (journalid);


DROP INDEX if exists docs.journalid_number_idx;

CREATE INDEX journalid_number_idx
  ON docs.journalid
  USING btree
  (rekvid, number, aasta);

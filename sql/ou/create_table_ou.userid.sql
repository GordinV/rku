-- auto-generated definition
drop TABLE if EXISTS ou.userid;

CREATE TABLE ou.userid (
  id           SERIAL                  NOT NULL
    CONSTRAINT userid_pkey
      PRIMARY KEY,
  rekvid       INTEGER                 NOT NULL,
  kasutaja     CHAR(50)                NOT NULL,
  ametnik      CHAR(254)               NOT NULL,
  parool       TEXT,
  muud         TEXT,
  last_login   TIMESTAMP DEFAULT now() NOT NULL,
  properties   JSONB,
  roles        JSONB,
  ajalugu      JSONB,
  status       INTEGER   DEFAULT 0
);

CREATE INDEX userid_rekvid
  ON ou.userid (rekvid, kasutaja);


GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE ou.userid TO db;



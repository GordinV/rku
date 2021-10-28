-- auto-generated definition
DROP TABLE IF EXISTS ou.taotlus_login;

CREATE TABLE ou.taotlus_login (
    id         SERIAL    NOT NULL
        CONSTRAINT taotlus_login_pkey
            PRIMARY KEY,
    parentid   INTEGER   NOT NULL,
    kpv        DATE      NOT NULL DEFAULT current_date,
    kasutaja   TEXT      NOT NULL,
    parool     TEXT,
    nimi       CHAR(254) NOT NULL,
    aadress    TEXT,
    email      TEXT,
    tel        TEXT,
    muud       TEXT,
    properties JSONB,
    ajalugu    JSONB,
    status     INTEGER            DEFAULT 1
);


GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE ou.taotlus_login TO db;



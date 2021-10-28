DROP TABLE IF EXISTS ou.config;

CREATE TABLE ou.config (
    id        SERIAL                    NOT NULL
        CONSTRAINT config__pkey
            PRIMARY KEY,
    rekvid    INTEGER                   NOT NULL,
    keel      INTEGER       DEFAULT 1   NOT NULL,
    toolbar1  INTEGER       DEFAULT 0   NOT NULL,
    toolbar2  INTEGER       DEFAULT 0   NOT NULL,
    toolbar3  INTEGER       DEFAULT 0   NOT NULL,
    number    VARCHAR(20)   DEFAULT ''  NOT NULL,
    arvround  NUMERIC(5, 2) DEFAULT 0.1 NOT NULL,
    asutusid  INTEGER       DEFAULT 0   NOT NULL,
    tahtpaev  INTEGER       DEFAULT 0,
    www1      VARCHAR(254)  DEFAULT '' :: CHARACTER VARYING,
    dokprop1  INTEGER       DEFAULT 0,
    dokprop2  INTEGER       DEFAULT 0,
    propertis JSONB
);


GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE ou.config TO db;

INSERT INTO ou.config (rekvid, keel)
SELECT id, 2
FROM ou.rekv
WHERE parentid < 999

/*
select * from ou.config
 */
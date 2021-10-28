DROP TABLE IF EXISTS libs.object;

CREATE TABLE libs.object (
    id         SERIAL,
    rekvid     INTEGER                     NOT NULL,
    asutusid   INTEGER,
    aadress    TEXT,
    muud       TEXT,
    properties JSONB,
    timestamp  TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT LOCALTIMESTAMP,
    CONSTRAINT object_pkey PRIMARY KEY (id),
    status     INTEGER                     NOT NULL DEFAULT 1,
    ajalugu    JSONB
)
    WITH (
        OIDS= FALSE
    );

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE libs.object TO db;

drop index if exists object_rekvid;

CREATE INDEX object_rekvid
    ON libs.object
        USING btree
        (rekvid)
    WHERE status <> 3;

drop index if exists object_rekvid;

CREATE INDEX object_asutusid
    ON libs.object
        USING btree
        (asutusid)
    WHERE status <> 3;

GRANT ALL ON SEQUENCE libs.object_id_seq TO db;
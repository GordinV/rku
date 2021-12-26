DROP TABLE IF EXISTS pank_vv;
DROP TABLE IF EXISTS docs.pank_vv;

CREATE TABLE docs.pank_vv (
    id          SERIAL,
    userid      INTEGER,
    doc_id      INTEGER,
    pank_id     TEXT,
    viitenumber TEXT,
    maksja      TEXT,
    iban        TEXT,
    summa       NUMERIC(12, 2),
    kpv         DATE,
    selg        TEXT,
    markused    TEXT,
    properties  JSONB,
    pank        TEXT,
    number      TEXT,
    isikukood   TEXT,
    aa          TEXT,
    TIMESTAMP   TIMESTAMP DEFAULT now(),
    CONSTRAINT pank_vv_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.pank_vv TO db;

GRANT ALL ON SEQUENCE docs.pank_vv_id_seq TO db;


ALTER TABLE docs.pank_vv add COLUMN if not EXISTS rekvid INTEGER not null;


CREATE INDEX IF NOT EXISTS pank_vv_doc_id_idx
    ON docs.pank_vv
        USING BTREE (doc_id);

CREATE INDEX IF NOT EXISTS pank_vv_rekvid_idx
    ON docs.pank_vv
        USING BTREE (rekvid);


/*
pank_id TEXT, summa NUMERIC(12, 2), kpv DATE, maksja TEXT, iban TEXT,
                                            selg TEXT, viitenr TEXT
 */
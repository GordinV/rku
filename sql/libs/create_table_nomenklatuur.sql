DROP TABLE IF EXISTS libs.nomenklatuur;

CREATE TABLE libs.nomenklatuur (
    id         SERIAL,
    rekvid     INTEGER        NOT NULL,
    dok        TEXT           NOT NULL,
    kood       CHARACTER(20)  NOT NULL,
    nimetus    TEXT           NOT NULL,
    uhik       TEXT,
    hind       NUMERIC(12, 4) NOT NULL DEFAULT 0,
    muud       TEXT,
    kogus      NUMERIC(12, 3) NOT NULL DEFAULT 0,
    formula    TEXT,
    status     INTEGER        NOT NULL DEFAULT 0,
    properties JSONB,
    CONSTRAINT nomenklatuur_pkey PRIMARY KEY (id)
)
    WITH (
        OIDS= false
    );

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE libs.nomenklatuur TO db;

GRANT ALL ON SEQUENCE libs.nomenklatuur_id_seq TO db;


CREATE INDEX nomenklatuur_rekvid
    ON libs.nomenklatuur
        USING btree
        (rekvid);



/*

select * from libs.nomenklatuur

insert into libs.nomenklatuur (rekvId, dok, kood, nimetus, uhik, hind, status)
	values (1, 'PVOPER', 'PAIGALDUS', 'PV paigaldamine', '', 100, 1)

*/
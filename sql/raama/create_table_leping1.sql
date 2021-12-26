DROP TABLE IF EXISTS docs.leping1 CASCADE;

CREATE TABLE docs.leping1 (
    id          SERIAL        NOT NULL,
    parentid    INTEGER       NOT NULL,
    asutusid    INTEGER       NOT NULL,
    objektid    INTEGER,
    rekvid      INTEGER       NOT NULL,
    "number"    CHARACTER(20) NOT NULL,
    kpv         DATE          NOT NULL,
    tahtaeg     DATE,
    selgitus    TEXT,
    dok         TEXT,
    muud        TEXT,
    propertieds JSONB,
    CONSTRAINT leping1_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.leping1 TO db;
GRANT ALL ON SEQUENCE docs.leping1_id_seq TO db;


DROP INDEX IF EXISTS leping1_parentid;

CREATE INDEX leping1_parentid
    ON docs.leping1
        USING btree
        (parentid);

DROP INDEX IF EXISTS leping1_asutusid;

CREATE INDEX leping1_asutusid
    ON docs.leping1
        USING btree
        (asutusid);

DROP INDEX IF EXISTS leping1_rekvid;

CREATE INDEX leping1_rekvid
    ON docs.leping1
        USING btree
        (rekvid);

DROP VIEW IF EXISTS cur_lepingud;

CREATE OR REPLACE VIEW cur_lepingud AS
SELECT d.id,
       l.rekvid,
       l.number,
       l.kpv,
       l.tahtaeg,
       l.selgitus      AS selgitus,
       a.nimetus::TEXT AS asutus,
       l.asutusid      AS asutusid,
       o.aadress       AS aadress
FROM docs.doc d
         JOIN docs.leping1 l ON l.parentid = d.id
         JOIN libs.asutus a ON l.asutusid = a.id
         JOIN libs.object o ON o.id = l.objektid;

GRANT SELECT ON TABLE cur_lepingud TO db;

GRANT ALL ON SEQUENCE docs.leping1_id_seq TO db;

CREATE UNIQUE INDEX leping1_parentid_idx
    ON docs.leping1 USING btree (parentid);


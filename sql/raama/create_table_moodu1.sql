DROP TABLE IF EXISTS docs.moodu1 CASCADE;

CREATE TABLE docs.moodu1 (
    id          SERIAL  NOT NULL,
    parentid    INTEGER NOT NULL,
    lepingid    INTEGER,
    kpv         DATE    NOT NULL,
    muud        TEXT,
    propertieds JSONB,
    CONSTRAINT moodu1_pkey PRIMARY KEY (id)
);

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE docs.moodu1 TO db;


DROP INDEX IF EXISTS moodu1_parentid;

CREATE INDEX moodu1_parentid
    ON docs.moodu1
        USING btree
        (parentid);

DROP INDEX IF EXISTS moodu1_lepingid;

CREATE INDEX moodu1_lepingid
    ON docs.moodu1
        USING btree
        (lepingid);

GRANT ALL ON SEQUENCE docs.moodu1_id_seq TO db;

ALTER TABLE docs.moodu1
    ADD CONSTRAINT leping_id_frk FOREIGN KEY (lepingid)
        REFERENCES docs.leping1 (parentid) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE RESTRICT;


DROP VIEW IF EXISTS cur_moodu;

CREATE OR REPLACE VIEW cur_moodu AS
SELECT d.id,
       d.rekvid,
       l1.number,
       m.kpv,
       a.nimetus::TEXT AS asutus,
       l1.asutusid     AS asutusid,
       l1.objektid,
       m.lepingid,
       o.aadress       AS objekt,
       array_to_string(m2.moodu,',') as moodu
FROM docs.doc d
         JOIN docs.moodu1 m ON m.parentid = d.id
         JOIN (SELECT parentid, array_agg(n.kood::TEXT || '-' || m2.kogus::TEXT || ' ' || n.uhik) AS moodu
               FROM docs.moodu2 m2
                        INNER JOIN libs.nomenklatuur n ON n.id = m2.nomid
               GROUP BY parentid
) m2 ON m.id = m2.parentid
         JOIN docs.leping1 l1 ON l1.parentid = m.lepingid
         JOIN libs.asutus a ON l1.asutusid = a.id
         JOIN libs.object o ON o.id = l1.objektid;

GRANT SELECT ON TABLE cur_moodu TO db;


/*
 select * from cur_moodu
 */
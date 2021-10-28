DROP VIEW IF EXISTS cur_lepingud;

CREATE VIEW cur_lepingud AS
SELECT d.id,
       l.rekvid,
       l.number,
       l.kpv,
       l.tahtaeg,
       l.selgitus AS selgitus,
       a.nimetus  AS asutus,
       l.asutusid,
       l.objektid,
       o.aadress  AS objekt
FROM docs.doc d
         JOIN docs.leping1 l ON l.parentid = d.id
         JOIN libs.asutus a ON l.asutusid = a.id
         LEFT JOIN libs.object o ON o.id = l.objektid;


GRANT SELECT ON TABLE cur_lepingud TO db;

/*

select * from cur_lepingud
 */
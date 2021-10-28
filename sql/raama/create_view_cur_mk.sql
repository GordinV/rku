DROP VIEW IF EXISTS cur_mk;
DROP VIEW IF EXISTS cur_pank;

CREATE OR REPLACE VIEW cur_pank AS
SELECT d.id,
       Mk.rekvid,
       Mk1.journalid,
       Mk.kpv,
       mk.maksepaev,
       Mk.number,
       Mk.selg,
       MK.OPT,
       CASE
           WHEN mk.opt = 2
               THEN Mk1.summa
           ELSE 0 :: NUMERIC(14, 2) END      AS deebet,
       CASE
           WHEN mk.opt = 1 OR coalesce(mk.opt, 0) = 0
               THEN Mk1.summa
           ELSE 0 :: NUMERIC(14, 2) END      AS kreedit,
       a.id                                  AS asutusid,
       coalesce(A.regkood, '')::VARCHAR(20)  AS regkood,
       coalesce(A.nimetus, '')::VARCHAR(254) AS nimetus,
       coalesce(N.kood, '')::VARCHAR(20)     AS kood,
       coalesce(Aa.arve, '') :: VARCHAR(20)  AS aa
FROM docs.doc d
         INNER JOIN docs.Mk mk ON mk.parentid = d.id
         INNER JOIN docs.Mk1 mk1 ON mk.id = mk1.parentid
         LEFT OUTER JOIN libs.Asutus a ON mk1.asutusId = a.ID
         LEFT OUTER JOIN libs.Nomenklatuur n ON mk1.nomid = n.id
         LEFT OUTER JOIN ou.Aa aa ON Mk.aaid = Aa.id;

GRANT SELECT ON TABLE cur_pank TO db;

/*
select * from cur_pank
limit 10
 */
DROP FUNCTION IF EXISTS docs.arve_kokkuvote(INTEGER, DATE, DATE);

CREATE OR REPLACE FUNCTION docs.arve_kokkuvote(l_rekvid INTEGER,
                                               kpv_start DATE DEFAULT make_date(year(current_date), 1, 1),
                                               kpv_end DATE DEFAULT current_date)
    RETURNS TABLE (
        asutus  TEXT,
        regkood TEXT,
        number  TEXT,
        kpv     DATE,
        summa   NUMERIC(12, 2),
        tasutud NUMERIC(12, 2),
        jaak    NUMERIC(12, 2),
        rekvid  INTEGER
    )
AS
$BODY$
WITH qryArved AS (
    SELECT c.nimetus::TEXT               AS asutus,
           c.regkood::TEXT               AS regkood,
           'Arve nr.:' || a.number::TEXT AS number,
           a.kpv                         AS kpv,
           a.summa::NUMERIC(12, 2)       AS summa,
           0::NUMERIC(12, 2)             AS tasutud,
           a.jaak::NUMERIC(12, 2)        AS jaak,
           d.rekvid                      AS rekvid
    FROM docs.doc d
             INNER JOIN docs.arv a ON a.parentid = d.id
             INNER JOIN libs.asutus c ON c.id = a.asutusid
             LEFT OUTER JOIN (SELECT doc_arv_id, sum(summa) AS summa FROM docs.arvtasu at GROUP BY doc_arv_id) t
                             ON t.doc_arv_id = d.id
    WHERE d.rekvid = l_rekvid
      AND (a.properties ->> 'tyyp' IS NULL OR a.properties ->> 'tyyp' <> 'ETTEMAKS')
      AND a.kpv >= kpv_start
      AND a.kpv <= kpv_end
),
     qrytasud AS (
         SELECT a.nimetus::TEXT                                                          AS asutus,
                a.regkood::TEXT                                                          AS regkood,
                'MK nr.:' || mk.number::TEXT                                             AS number,
                mk.maksepaev                                                             AS kpv,
                0                                                                        AS summa,
                (CASE WHEN mk.opt = 1 THEN -1 ELSE 1 END) * mk1.summa::NUMERIC(12, 2)    AS tasutud,
                -1 * (CASE WHEN mk.opt = 1 THEN -1 ELSE 1 END) * mk.jaak::NUMERIC(12, 2) AS jaak,
                d.rekvid                                                                 AS rekvid
         FROM docs.doc D
                  INNER JOIN docs.mk mk ON mk.parentid = D.id
                  INNER JOIN (SELECT mk1.parentid, mk1.asutusid, sum(summa) AS summa
                              FROM docs.mk1 mk1
                              GROUP BY mk1.parentid, mk1.asutusid
         ) mk1 ON mk.id = mk1.parentid
                  INNER JOIN libs.asutus a ON a.id = mk1.asutusid
         WHERE D.status <> 3
           AND mk.maksepaev >= kpv_start
           AND mk.maksepaev <= kpv_end
           AND D.rekvid = l_rekvid
         UNION ALL
         SELECT a.nimetus::TEXT                                                        AS asutus,
                a.regkood::TEXT                                                        AS regkood,
                'Kassaorder nr.:' || k1.number::TEXT                                                        AS number,
                k1.kpv                                                                 AS kpv,
                0                                                                      AS summa,
                (CASE WHEN k1.tyyp = 2 THEN -1 ELSE 1 END) * mk1.summa::NUMERIC(12, 2) AS tasutud,
                0::NUMERIC(12, 2)                                                      AS jaak,
                d.rekvid                                                               AS rekvid
         FROM docs.doc D
                  INNER JOIN docs.korder1 k1 ON k1.parentid = D.id
                  INNER JOIN (SELECT k2.parentid, sum(summa) AS summa
                              FROM docs.korder2 k2
                              GROUP BY k2.parentid
         ) mk1 ON k1.id = mk1.parentid
                  INNER JOIN libs.asutus a ON a.id = k1.asutusid
         WHERE D.status <> 3
           AND k1.kpv >= kpv_start
           AND k1.kpv <= kpv_end
           AND D.rekvid = l_rekvid)

SELECT *
FROM qryArved
UNION ALL
SELECT *
FROM qrytasud


$BODY$
    LANGUAGE SQL
    VOLATILE
    COST 100;


GRANT EXECUTE ON FUNCTION docs.arve_kokkuvote(INTEGER, DATE, DATE) TO db;

/*

SELECT *
FROM docs.arve_kokkuvote(8, '2021-01-01', '2021-12-31')


select * from ou.rekv
*/

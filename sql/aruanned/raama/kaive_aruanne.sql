--DROP FUNCTION IF EXISTS lapsed.saldo_ja_kaive(INTEGER, DATE, DATE);
DROP FUNCTION IF EXISTS docs.kaive_aruanne(INTEGER, DATE, DATE);

CREATE OR REPLACE FUNCTION docs.kaive_aruanne(l_rekvid INTEGER,
                                              kpv_start DATE DEFAULT make_date(year(current_date), 1, 1),
                                              kpv_end DATE DEFAULT current_date)
    RETURNS TABLE (
        id         BIGINT,
        period     DATE,
        nimi       TEXT,
        isikukood  TEXT,
        isik_id    INTEGER,
        alg_saldo  NUMERIC(14, 4),
        arvestatud NUMERIC(14, 4),
        laekumised NUMERIC(14, 4),
        tagastused NUMERIC(14, 4),
        jaak       NUMERIC(14, 4),
        rekvid     INTEGER
    )
AS
$BODY$
SELECT count(*) OVER (PARTITION BY report.isik_id) AS id,
       kpv_start::DATE                             AS period,
       a.nimetus::TEXT                             AS nimi,
       a.regkood::TEXT                             AS isikukood,
       a.id::INTEGER                               AS isik_id,
       alg_saldo::NUMERIC(14, 4),
       arvestatud::NUMERIC(14, 4),
       laekumised::NUMERIC(14, 4),
       tagastused::NUMERIC(14, 4),
       (alg_saldo + arvestatud - laekumised + tagastused)::NUMERIC(14, 4),
       report.rekv_id
FROM (
         WITH alg_saldo AS (
             SELECT isik_id, rekv_id, sum(summa) AS jaak
             FROM (
                      -- laekumised
                      SELECT -1 * (CASE WHEN mk.opt = 2 THEN 1 ELSE -1 END) * mk1.summa AS summa,
                             mk1.asutusid                                               AS isik_id,
                             d.rekvid                                                   AS rekv_id
                      FROM docs.doc d
                               INNER JOIN docs.Mk mk ON mk.parentid = d.id
                               INNER JOIN docs.Mk1 mk1 ON mk.id = mk1.parentid

                      WHERE d.status <> 3
                        AND d.rekvid = l_rekvid
                        AND mk.maksepaev < kpv_start
                      UNION ALL
                      SELECT -1 * sum(mk1.summa) AS summa,
                             mk.asutusid         AS isik_id,
                             d.rekvid            AS rekv_id
                      FROM docs.doc d
                               INNER JOIN docs.korder1 mk ON mk.parentid = d.id
                               INNER JOIN docs.korder2 mk1 ON mk.id = mk1.parentid
                      WHERE d.status <> 3
                        AND mk.tyyp = 1
                        AND mk1.summa > 0
                        AND d.rekvid = l_rekvid
                        AND mk.kpv < kpv_start
                      GROUP BY mk.asutusid, d.rekvid
                      UNION ALL
                      SELECT a.summa    AS summa,
                             a.asutusid AS isik_id,
                             d.rekvid   AS rekv_id
                      FROM docs.doc d
                               INNER JOIN docs.arv a ON a.parentid = d.id AND a.liik = 0 -- только счета исходящие
                      WHERE coalesce((a.properties ->> 'tyyp')::TEXT, '') <> 'ETTEMAKS'
                        AND d.rekvid = l_rekvid
                        AND a.liik = 0 -- только счета исходящие
                        AND a.kpv < kpv_start
-- mahakandmine
                      UNION ALL
                      SELECT -1 * a.summa AS summa,
                             arv.asutusid AS isik_id,
                             a.rekvid     AS rekv_id
                      FROM docs.arvtasu a
                               INNER JOIN docs.arv arv ON a.doc_arv_id = arv.parentid

                      WHERE a.pankkassa = 3 -- только проводки
                        AND a.rekvid = l_rekvid
                        AND a.kpv < kpv_start
                        AND a.status <> 3
                        AND (arv.properties ->> 'tyyp' IS NULL OR
                             arv.properties ->> 'tyyp' <> 'ETTEMAKS') -- уберем предоплаты

                  ) alg_saldo
             GROUP BY isik_id, rekv_id
         ),

              laekumised AS (
                  SELECT sum(mk1.summa) AS summa,
                         mk1.asutusid   AS isik_id,
                         d.rekvid       AS rekv_id
                  FROM docs.doc d
                           INNER JOIN docs.Mk mk ON mk.parentid = d.id
                           INNER JOIN docs.Mk1 mk1 ON mk.id = mk1.parentid
                  WHERE d.status <> 3
                    AND mk.opt = 2
                    AND mk1.summa > 0
                    AND d.rekvid = l_rekvid
                    AND mk.maksepaev >= kpv_start
                    AND mk.maksepaev <= kpv_end
                  GROUP BY mk1.asutusid, d.rekvid
                  UNION ALL
                  SELECT sum(mk1.summa) AS summa,
                         mk.asutusid    AS isik_id,
                         d.rekvid       AS rekv_id
                  FROM docs.doc d
                           INNER JOIN docs.korder1 mk ON mk.parentid = d.id
                           INNER JOIN docs.korder2 mk1 ON mk.id = mk1.parentid
                  WHERE d.status <> 3
                    AND mk.tyyp = 1
                    AND mk1.summa > 0
                    AND d.rekvid = l_rekvid
                    AND mk.kpv >= kpv_start
                    AND mk.kpv <= kpv_end
                  GROUP BY mk.asutusid, d.rekvid
              ),
              tagastused AS (
                  SELECT sum(CASE WHEN mk.opt = 2 THEN -1 ELSE 1 END * mk1.summa) AS summa,
                         mk1.asutusid                                             AS isik_id,
                         d.rekvid                                                 AS rekv_id
                  FROM docs.doc d
                           INNER JOIN docs.Mk mk ON mk.parentid = d.id
                           INNER JOIN docs.Mk1 mk1 ON mk.id = mk1.parentid
                  WHERE d.status <> 3
                    AND (mk.opt = 1 OR (mk.opt = 2 AND mk1.summa < 0))
                    AND d.rekvid = l_rekvid
                    AND mk.maksepaev >= kpv_start
                    AND mk.maksepaev <= kpv_end
                  GROUP BY mk1.asutusid, d.rekvid
              ),

              arvestatud AS (
                  SELECT a.asutusid                     AS isik_id,
                         sum(a1.summa) ::NUMERIC(14, 4) AS arvestatud,
                         D.rekvid::INTEGER              AS rekv_id
                  FROM docs.doc D
                           INNER JOIN docs.arv a ON a.parentid = D.id AND a.liik = 0 -- только счета исходящие
                           INNER JOIN (SELECT a1.parentid             AS arv_id,
                                              sum(a1.summa) AS summa
                                       FROM docs.arv1 a1
                                                INNER JOIN docs.arv a ON a.id = a1.parentid AND
                                                                         (a.properties ->> 'tyyp' IS NULL OR a.properties ->> 'tyyp' <> 'ETTEMAKS')
                                           AND a.liik = 0 -- только счета исходящие

                                                INNER JOIN docs.doc D ON D.id = a.parentid AND D.status <> 3
                                       GROUP BY a1.parentid) a1
                                      ON a1.arv_id = a.id
                  WHERE COALESCE((a.properties ->> 'tyyp')::TEXT, '') <> 'ETTEMAKS'
                    AND D.rekvid = l_rekvid
                    AND a.liik = 0 -- только счета исходящие
                    AND a.kpv >= kpv_start
                    AND a.kpv <= kpv_end
                  GROUP BY a.asutusid, D.rekvid
              )
         SELECT sum(alg_saldo)  AS alg_saldo,
                sum(arvestatud) AS arvestatud,
                sum(laekumised) AS laekumised,
                sum(tagastused) AS tagastused,
                qry.rekv_id,
                qry.isik_id
         FROM (
                  -- alg.saldo
                  SELECT a.jaak    AS alg_saldo,
                         0         AS arvestatud,
                         0         AS laekumised,
                         0         AS tagastused,
                         a.rekv_id AS rekv_id,
                         a.isik_id
                  FROM alg_saldo a
                  UNION ALL
                  -- laekumised
                  SELECT 0         AS alg_saldo,
                         0         AS arvestatud,
                         l.summa   AS laekumised,
                         0         AS tagastused,
                         l.rekv_id AS rekv_id,
                         l.isik_id
                  FROM laekumised l
                  UNION ALL
                  -- tagastused
                  SELECT 0                    AS alg_saldo,
                         0                    AS arvestatud,
                         0                    AS laekumised,
                         coalesce(t.summa, 0) AS tagastused,
                         t.rekv_id            AS rekv_id,
                         t.isik_id
                  FROM tagastused t
                  UNION ALL
                  -- arvestused
                  SELECT 0            AS alg_saldo,
                         k.arvestatud AS arvestatud,
                         0            AS laekumised,
                         0            AS tagastused,
                         k.rekv_id    AS rekv_id,
                         k.isik_id
                  FROM arvestatud k
              ) qry
         GROUP BY isik_id, rekv_id
     ) report
         INNER JOIN libs.asutus a ON report.isik_id = a.id

$BODY$
    LANGUAGE SQL
    VOLATILE
    COST 100;


GRANT EXECUTE ON FUNCTION docs.kaive_aruanne(INTEGER, DATE, DATE) TO db;


/*
explain
select *
FROM docs.kaive_aruanne(1, '2021-11-01', '2021-12-31') qry
*/



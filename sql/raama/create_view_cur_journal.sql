-- View: public.cur_ladu_jaak

DROP VIEW IF EXISTS cur_journal CASCADE ;

CREATE OR REPLACE VIEW cur_journal AS
SELECT to_char(d.created, 'DD.MM.YYYY HH:MM')                                                 AS created,
       to_char(d.lastupdate, 'DD.MM.YYYY HH:MM')                                              AS lastupdate,
       s.nimetus                                                                              AS status,
       d.id                                                                                   AS id,
       j.kpv                                                                                  AS kpv,
       jid.number,
       j.id                                                                                   AS journalid,
       j.rekvId,
       j.asutusid,
       month(j.kpv) :: INTEGER                                                                AS kuu,
       year(j.kpv) :: INTEGER                                                                 AS aasta,
       coalesce(regexp_replace(j.selg, '"', '`'), '') :: VARCHAR(254)                         AS selg,
       COALESCE(j.dok, '') :: VARCHAR(50)                                                     AS dok,
       COALESCE(j.objekt, '') :: VARCHAR(20)                                                  AS objekt,
       j.muud :: CHARACTER VARYING(254)                                                       AS muud,
       j1.deebet,
       j1.kreedit,
       j1.summa,
       COALESCE(j1.proj, '') :: VARCHAR(20)                                                   AS proj,
       COALESCE(ltrim(rtrim(a.nimetus)) || ' ' || ltrim(rtrim(a.omvorm)), '') :: VARCHAR(120) AS asutus,
       COALESCE(j1.tunnus, '') :: VARCHAR(20)                                                 AS tunnus,
       COALESCE(u.ametnik, '') :: VARCHAR(120)                                                AS kasutaja,
       ltrim(rtrim(r.nimetus)):: VARCHAR(254)                                                 AS rekvAsutus
FROM docs.journal j
         INNER JOIN docs.doc D ON D.id = j.parentid
         INNER JOIN libs.library S ON S.kood = D.status :: TEXT AND S.library = 'STATUS'
         INNER JOIN docs.journalid jid ON j.id = jid.journalid
         INNER JOIN docs.journal1 j1 ON j.id = j1.parentid
         INNER JOIN ou.rekv r ON r.id = j.rekvid
         LEFT JOIN libs.asutus a ON a.id = j.asutusid
         LEFT OUTER JOIN ou.userid u ON u.id = j.userid
WHERE D.status <> 3;

GRANT SELECT ON TABLE cur_journal TO db;

/*
select j.*
            from cur_journal j
*/
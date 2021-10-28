'use strict';
//var co = require('co');
let now = new Date();

const Arv = {
    selectAsLibs: `SELECT *, $2 AS rekvid
                   FROM com_arved a
                   WHERE (a.rekvId = $1::INTEGER)`, //$1 - rekvid, $2 userid
    select: [
        {
            sql: `SELECT d.id,
                         $2 :: INTEGER                                                     AS userid,
                         d.bpm,
                         trim(l.nimetus)                                                   AS doc,
                         trim(l.kood)                                                      AS doc_type_id,
                         d.status                                                          AS doc_status,
                         trim(a.number) :: VARCHAR(20)                                     AS number,
                         a.rekvId,
                         a.liik,
                         a.operid,
                         to_char(a.kpv, 'YYYY-MM-DD')                                      AS kpv,
                         a.asutusid,
                         a.arvId,
                         trim(coalesce(a.lisa, '')) :: VARCHAR(120)                        AS lisa,
                         to_char(a.tahtaeg, 'YYYY-MM-DD')                                  AS tahtaeg,
                         a.kbmta,
                         a.kbm,
                         a.summa,
                         a.tasud,
                         trim(a.tasudok)                                                   AS tasudok,
                         a.muud,
                         a.jaak,
                         coalesce(a.objektId, 0)::INTEGER                                  AS objektId,
                         trim(a.objekt)                                                    AS objekt,
                         asutus.regkood,
                         trim(asutus.nimetus)                                              AS asutus,
                         asutus.aadress,
                         (asutus.properties ->> 'kmkr') :: VARCHAR(20)                     AS kmkr,
                         a.doklausid,
                         a.journalid,
                         (d.history -> 0 ->> 'user') :: VARCHAR(120)                       AS koostaja,
                         coalesce((a.properties ->> 'aa')::TEXT, qry_aa.arve)::VARCHAR(20) AS aa,
                         coalesce((a.properties ->> 'viitenr')::TEXT, '')::VARCHAR(120)    AS viitenr
                  FROM docs.doc d
                           INNER JOIN libs.library l ON l.id = d.doc_type_id
                           INNER JOIN docs.arv a ON a.parentId = d.id
                           INNER JOIN libs.asutus AS asutus ON asutus.id = a.asutusId
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                          ,
                       (SELECT arve
                        FROM ou.aa aa
                                 INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                        WHERE aa.parentid = u.rekvid
                          AND NOT empty(default_::INTEGER)
                          AND NOT empty(kassa::INTEGER)
                          AND kassa = 1
                        LIMIT 1) qry_aa
                  WHERE d.id = $1`,
            sqlAsNew: `SELECT $1 :: INTEGER                                                                AS id,
                              $2 :: INTEGER                                                                AS userid,
                              to_char(now(), 'DD.MM.YYYY HH:MM:SS') :: TEXT                                AS created,
                              to_char(now(), 'DD.MM.YYYY HH:MM:SS') :: TEXT                                AS lastupdate,
                              NULL                                                                         AS bpm,
                              trim(l.nimetus)                                                              AS doc,
                              trim(l.kood)                                                                 AS doc_type_id,
                              0                                                                            AS doc_status,
                              (SELECT arve
                               FROM ou.aa aa
                               WHERE aa.parentid = u.rekvid
                                 AND NOT empty(default_::INTEGER)
                                 AND NOT empty(kassa::INTEGER)
                                 AND kassa = 1
                               LIMIT 1)::VARCHAR(20)                                                       AS aa,

                              docs.sp_get_number(u.rekvId, 'ARV', year(current_date), NULL) :: VARCHAR(20) AS number,
                              0.00                                                                         AS summa,
                              NULL :: INTEGER                                                              AS rekvId,
                              0                                                                            AS liik,
                              NULL :: INTEGER                                                              AS operid,
                              now() :: DATE                                                                AS kpv,
                              NULL :: INTEGER                                                              AS asutusid,
                              NULL :: INTEGER                                                              AS arvId,
                              '' :: VARCHAR(120)                                                           AS lisa,
                              (now() + INTERVAL '14 days') :: DATE                                         AS tahtaeg,
                              0 :: NUMERIC                                                                 AS kbmta,
                              0.00 :: NUMERIC                                                              AS kbm,
                              0 :: NUMERIC(14, 2)                                                          AS summa,
                              NULL :: DATE                                                                 AS tasud,
                              NULL :: VARCHAR(20)                                                          AS tasudok,
                              NULL :: TEXT                                                                 AS muud,
                              0.00                                                                         AS jaak,
                              0 :: INTEGER                                                                 AS objektId,
                              NULL :: VARCHAR(20)                                                          AS objekt,
                              NULL :: VARCHAR(20)                                                          AS regkood,
                              NULL :: VARCHAR(120)                                                         AS asutus,
                              NULL :: TEXT                                                                 AS aadress,
                              NULL :: VARCHAR(120)                                                         AS kmkr,
                              NULL :: INTEGER                                                              AS doklausid,
                              NULL :: VARCHAR(120)                                                         AS dokprop,
                              NULL :: TEXT                                                                 AS konto,
                              NULL :: TEXT                                                                 AS kbmkonto,
                              NULL :: INTEGER                                                              AS journalid,
                              NULL :: INTEGER                                                              AS laus_nr,
                              NULL :: VARCHAR(120)                                                         AS koostaja,
                              0 ::INTEGER                                                                  AS is_show_journal,
                              ''::VARCHAR(120)                                                             AS viitenr
                       FROM libs.library l,
                            ou.userid u
                       WHERE l.library = 'DOK'
                         AND l.kood = 'ARV'
                         AND u.id = $2 :: INTEGER`,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
        {
            sql: `SELECT a1.id,
                         $2 :: INTEGER                   AS userid,
                         a1.nomid,
                         a1.kogus,
                         a1.hind,
                         a1.kbm,
                         a1.kbmta,
                         a1.summa,
                         trim(n.kood) :: VARCHAR(20)     AS kood,
                         trim(n.nimetus) :: VARCHAR(254) AS nimetus,
                         a1.tunnus,
                         a1.proj,
                         a1.konto,
                         NULL :: TEXT                    AS vastisik,
                         NULL :: TEXT                    AS formula,
                         n.uhik,
                         a1.muud
                  FROM docs.arv1 AS a1
                           INNER JOIN docs.arv a ON a.id = a1.parentId
                           INNER JOIN libs.nomenklatuur n ON n.id = a1.nomId
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                  WHERE a.parentid = $1 :: INTEGER`,
            query: null,
            multiple: true,
            alias: 'details',
            data: []
        },
        {
            sql: `SELECT rd.id, $2 :: INTEGER AS userid, trim(l.kood) AS doc_type, trim(l.nimetus) AS name
                  FROM docs.doc d
                           LEFT OUTER JOIN docs.doc rd ON rd.id IN (SELECT unnest(d.docs_ids))
                           LEFT OUTER JOIN libs.library l ON rd.doc_type_id = l.id
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                  WHERE d.id = $1 :: INTEGER`,
            query: null,
            multiple: true,
            alias: 'relations',
            data: []
        },
        {
            sql: `SELECT Arvtasu.id,
                         arvtasu.kpv,
                         arvtasu.summa,
                         'MK' :: VARCHAR(20) AS dok,
                         'PANK' :: VARCHAR   AS liik,
                         pankkassa,
                         doc_tasu_id,
                         'EUR' :: VARCHAR    AS valuuta,
                         1 :: NUMERIC        AS kuurs
                  FROM docs.arvtasu arvtasu
                           INNER JOIN docs.mk mk ON (arvtasu.doc_tasu_id = mk.parentid AND arvtasu.pankkassa = 1)
                           INNER JOIN docs.mk1 mk1 ON (mk.id = mk1.parentid)
                  WHERE Arvtasu.doc_arv_id = $1
                    AND arvtasu.summa <> 0
                    AND arvtasu.status <> 3
                  UNION ALL
                  SELECT Arvtasu.id,
                         arvtasu.kpv,
                         arvtasu.summa,
                         'KASSAORDER' :: VARCHAR(20)   AS dok,
                         'KASSA' :: VARCHAR            AS liik,
                         pankkassa,
                         korder1.journalid,
                         doc_tasu_id,
                         coalesce(journalid.number, 0) AS number,
                         'EUR' :: VARCHAR              AS valuuta,
                         1 :: NUMERIC                  AS kuurs
                  FROM docs.arvtasu arvtasu
                           INNER JOIN docs.korder1 korder1
                                      ON (arvtasu.doc_tasu_id = korder1.parentid AND arvtasu.pankkassa = 2)
                  WHERE Arvtasu.doc_arv_id = $1
                    AND arvtasu.summa <> 0
                    AND arvtasu.status <> 3
                  UNION ALL
                  SELECT Arvtasu.id,
                         arvtasu.kpv,
                         arvtasu.summa,
                         '' :: VARCHAR(20) AS dok,
                         'MUUD' :: VARCHAR AS liik,
                         pankkassa,
                         0                 AS journalid,
                         NULL,
                         0                 AS number,
                         'EUR' :: VARCHAR  AS valuuta,
                         1 :: NUMERIC      AS kuurs
                  FROM docs.arvtasu arvtasu
                  WHERE Arvtasu.doc_arv_id = $1
                    AND arvtasu.summa <> 0
                    AND arvtasu.status <> 3
                    AND arvtasu.pankkassa IN (0, 4)

            `,
            query: null,
            multiple: true,
            alias: 'queryArvTasu',
            data: []
        },
        {
            sql: `SELECT docs.check_arv_number($1::integer, $2::JSON)::integer as tulemus`, //$1 - rekvId, $2 - params ->'{"tyyp":1, "number":"10", "aasta": 2017, "asutus": 5155}'
            query: null,
            multuple: false,
            alias: 'validate_arve_number',
            data: []

        },
        {
            sql: `SELECT *
                  FROM docs.check_arv_jaak($1, $2)`, //$1 - docId, $2 userId
            query: null,
            multuple: false,
            alias: 'check_arv_jaak',
            data: []
        },
        {
            sql: `SELECT *
                  FROM libs.asutus
                  WHERE regkood = $1
                  ORDER BY staatus
                  LIMIT 1`,
            query: null,
            multiple: false,
            alias: 'validate_asutus',
            data: []
        },


    ],
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "2px", show: false},
            {id: "number", name: "Number", width: "10%"},
            {id: "kpv", name: "Kuupaev", width: "15%"},
            {id: "summa", name: "Summa", width: "15%"},
            {id: "tahtaeg", name: "Tähtaeg", width: "15%"},
            {id: "jaak", name: "Jääk", width: "15%"},
            {id: "tasud", name: "Tasud", width: "15%"},
            {id: "asutus", name: "Asutus", width: "20%"},
        ],
        sqlString: `SELECT a.id,
                           arv_id,
                           number :: VARCHAR(20),
                           rekvid,
                           to_char(kpv, 'DD.MM.YYYY')                 AS kpv,
                           summa,
                           to_char(tahtaeg, 'DD.MM.YYYY')             AS tahtaeg,
                           jaak,
                           lisa,
                           tasud,
                           tasudok,
                           userid,
                           asutus :: VARCHAR(254),
                           regkood::VARCHAR(20),
                           omvorm::VARCHAR(20),
                           aadress::TEXT,
                           email::VARCHAR(254),
                           asutusid,
                           journalid,
                           liik,
                           ametnik,
                           objektid,
                           objekt :: VARCHAR(254),
                           markused,
                           docs_ids,
                           coalesce(a.arve, qry_aa.arve)::VARCHAR(20) AS aa,
                           a.viitenr::VARCHAR(120)                    AS viitenr
                    FROM cur_arved a,
                         (SELECT arve
                          FROM ou.aa aa
                          WHERE aa.parentid = $1
                            AND NOT empty(default_::INTEGER)
                            AND NOT empty(kassa::INTEGER)
                            AND kassa = 1
                          LIMIT 1) qry_aa,
                         libs.asutus_user_id au
                    WHERE a.rekvId = $1::INTEGER
                      AND au.asutus_id = a.asutusid
                      AND au.user_id = $2::INTEGER`,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curArved'
    },
    returnData: {
        row: {},
        details: [],
        relations: [],
        gridConfig: [
            {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
            {id: 'nomid', name: 'nomId', width: '0px', show: false, type: 'text', readOnly: false},
            {
                id: 'kood',
                name: 'Kood',
                width: '100px',
                show: true,
                type: 'select',
                readOnly: false,
                dataSet: 'nomenclature',
                valueFieldName: 'nomid'
            },
            {id: 'nimetus', name: 'Nimetus', width: '300px', show: true, readOnly: true},
            {id: 'hind', name: 'Hind', width: '100px', show: true, type: 'number', readOnly: false},
            {id: 'kogus', name: 'kogus', width: '100px', show: true, type: 'number', readOnly: false},
            {id: 'kbm', name: 'Käibemaks', width: '100px', show: true, type: 'number', readOnly: false},
            {id: 'summa', name: 'Summa', width: '100px', show: true, type: 'number', readOnly: false}
        ]
    },
    saveDoc: `select docs.sp_salvesta_arv($1::json, $2::integer, $3::integer) as id`,
    requiredFields: [
        {
            name: 'kpv',
            type: 'D',
            min: now.setFullYear(now.getFullYear() - 1),
            max: now.setFullYear(now.getFullYear() + 1)
        },
        {
            name: 'tahtaeg',
            type: 'D',
            min: now.setFullYear(now.getFullYear() - 1),
            max: now.setFullYear(now.getFullYear() + 1)
        },
        {name: 'asutusid', type: 'N', min: null, max: null},
        {name: 'summa', type: 'N', min: -9999999, max: 999999}
    ],
    executeCommand: {
        command: `select docs.sp_kooperi_arv($1::integer, $2::integer) as result`,
        type: 'sql',
        alias: 'kooperiArv'
    },
    getLog: {
        command: `SELECT ROW_NUMBER() OVER ()                                                                        AS id,
                         (ajalugu ->> 'user')::VARCHAR(20)                                                           AS kasutaja,
                         coalesce(to_char((ajalugu ->> 'created')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS koostatud,
                         coalesce(to_char((ajalugu ->> 'updated')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS muudatud,
                         coalesce(to_char((ajalugu ->> 'print')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS prinditud,
                         coalesce(to_char((ajalugu ->> 'email')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'), '')::VARCHAR(20) AS
                                                                                                                        email,
                         coalesce(to_char((ajalugu ->> 'earve')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS earve,
                         coalesce(to_char((ajalugu ->> 'deleted')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS kustutatud
                  FROM (
                           SELECT jsonb_array_elements(history) AS ajalugu, d.id, d.rekvid
                           FROM docs.doc d,
                                ou.userid u
                           WHERE d.id = $1
                             AND u.id = $2
                       ) qry`,
        type: "sql",
        alias: "getLogs"
    },

};

module.exports = Arv;


'use strict';

let now = new Date();

const Sorder = {
    select: [
        {
            sql: `SELECT d.id,
                         d.docs_ids,
                         d.bpm,
                         trim(l.nimetus)::VARCHAR(254)             AS doc,
                         trim(l.kood)::VARCHAR(20)                 AS doc_type_id,
                         k.number::VARCHAR(20)                     AS number,
                         k.summa,
                         k.kassaid                                 AS kassa_id,
                         trim(aa.nimetus)                          AS kassa,
                         k.rekvId,
                         to_char(k.kpv, 'YYYY-MM-DD')              AS kpv,
                         k.asutusid,
                         trim(coalesce(k.dokument, ''))            AS dokument,
                         k.alus,
                         k.muud,
                         k.nimi,
                         coalesce(k.aadress, '')                   AS aadress,
                         k.tyyp,
                         asutus.regkood,
                         trim(asutus.nimetus)                      AS asutus,
                         k.arvid,
                         ('Number:' || arv.number :: TEXT || ' Kuupäev:' || arv.kpv :: TEXT || ' Jääk:' ||
                          arv.jaak :: TEXT)                        AS arvnr,
                         k.doklausid,
                         (SELECT sum(summa)
                          FROM docs.korder2 k2
                          WHERE parentid = k.id) :: NUMERIC(12, 2) AS kokku,
                         (d.history -> 0 ->> 'user')::VARCHAR(120) AS koostaja

                  FROM docs.doc d
                           INNER JOIN libs.library l ON l.id = d.doc_type_id
                           INNER JOIN docs.korder1 k ON k.parentId = d.id
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                           LEFT OUTER JOIN libs.asutus AS asutus ON asutus.id = k.asutusId
                           LEFT OUTER JOIN ou.aa AS aa ON k.kassaid = aa.Id
                           LEFT OUTER JOIN docs.arv AS arv ON k.arvid = arv.Id
                  WHERE d.id = $1`,
            sqlAsNew: `SELECT $1 :: INTEGER                                                     AS id,
                              $2 :: INTEGER                                                     AS userid,
                              NULL                                                              AS bpm,
                              trim(l.nimetus)                                                   AS doc,
                              trim(l.kood)                                                      AS doc_type_id,
                              docs.sp_get_number((SELECT rekvid
                                                  FROM ou.userid
                                                  WHERE id = $2)::INTEGER, 'SORDER'::TEXT,
                                                 year(now()::DATE), NULL::INTEGER)::VARCHAR(20) AS number,
                              0                                                                 AS summa,
                              aa.id                                                             AS kassa_id,
                              trim(aa.name)                                                     AS kassa,
                              NULL::INTEGER                                                     AS rekvId,
                              to_char(current_date, 'YYYY-MM-DD')                               AS kpv,
                              NULL::INTEGER                                                     AS asutusid,
                              NULL::VARCHAR(120)                                                AS dokument,
                              NULL::TEXT                                                        AS alus,
                              NULL::TEXT                                                        AS muud,
                              NULL::TEXT                                                        AS nimi,
                              NULL::TEXT                                                        AS aadress,
                              1                                                                 AS tyyp,
                              0::NUMERIC(12, 2)                                                 AS summa,
                              NULL::VARCHAR(20)                                                 AS regkood,
                              NULL::VARCHAR(254)                                                AS asutus,
                              NULL::INTEGER                                                     AS arvid,
                              NULL::INTEGER                                                     AS arvnr,
                              0::NUMERIC                                                        AS kokku
                       FROM libs.library l,
                            (SELECT id,
                                    trim(nimetus) AS name
                             FROM ou.aa
                             WHERE kassa = 1
                             ORDER BY default_
                             LIMIT 1) AS aa
                       WHERE l.library = 'DOK'
                         AND l.kood = 'SORDER'`,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
        {
            sql: `SELECT k1.id,
                         $2 :: INTEGER                AS userid,
                         trim(n.kood)::VARCHAR(20)    AS kood,
                         trim(n.nimetus)::VARCHAR(20) AS nimetus,
                         trim(n.uhik)                 AS uhik,
                         k1.*
                  FROM docs.korder2 AS k1
                           INNER JOIN docs.korder1 k ON k.id = k1.parentId
                           INNER JOIN libs.nomenklatuur n ON n.id = k1.nomid
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                  WHERE k.parentid = $1`,
            query: null,
            multiple: true,
            alias: 'details',
            data: []
        },
        {
            sql: `SELECT rd.id,
                         $2 :: INTEGER   AS userid,
                         trim(l.kood)    AS doc_type,
                         trim(l.nimetus) AS name
                  FROM docs.doc d
                           LEFT OUTER JOIN docs.doc rd ON rd.id IN (SELECT unnest(d.docs_ids))
                           LEFT OUTER JOIN libs.library l ON rd.doc_type_id = l.id
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                  WHERE d.id = $1`,
            query: null,
            multiple: true,
            alias: 'relations',
            data: []
        }

    ],
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "1px", show: false},
            {id: "kpv", name: "Kuupaev", width: "15%"},
            {id: "number", name: "Number", width: "20%"},
            {id: "nimi", name: "Nimi", width: "30%"},
            {id: "dokument", name: "Dokument", width: "20%"},
            {id: "deebet", name: "Summa", width: "15%"},
        ],
        sqlString: `SELECT id, to_char(kpv,'DD.MM.YYYY') as kpv, number, nimi, dokument, deebet, $2 AS user_id
                    FROM cur_korder k
                    WHERE k.rekvId = $1
                      AND deebet <> 0`,     // $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curKorder'
    },
    returnData: {
        row: {},
        relations: [],
        details: [],
        gridConfig: [
            {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
            {id: 'nimetus', name: 'Nimetus', width: '100px', show: true, type: 'text', readOnly: false},
            {id: 'summa', name: 'Summa', width: '100px', show: true, type: 'number', readOnly: false},
            {id: 'konto', name: 'Korr.konto', width: '100px', show: true, type: 'text', readOnly: false},
            {id: 'tunnus', name: 'Tunnus', width: '100px', show: true, type: 'text', readOnly: false},
            {id: 'proj', name: 'Projekt', width: '100px', show: true, type: 'text', readOnly: false}
        ]
    },
    saveDoc: `select docs.sp_salvesta_korder($1::json, $2::integer, $3::integer) as id`,
    deleteDoc: `SELECT error_code, result, error_message
                FROM docs.sp_delete_korder($1::INTEGER, $2::INTEGER)`, // $1 - userId, $2 - docId
    requiredFields: [
        {
            name: 'kpv',
            type: 'D',
            min: now.setFullYear(now.getFullYear() - 1),
            max: now.setFullYear(now.getFullYear() + 1)
        },
        {name: 'asutusid', type: 'N', min: null, max: null},
        {name: 'summa', type: 'N', min: -9999999, max: 999999}
    ],
    bpm: [],
    executeTask: (task, docId, userId) => {
        // выполнит задачу, переданную в параметре

        let executeTask = task;
        if (executeTask.length == 0) {
            executeTask = ['start'];
        }

        let taskFunction = eval(executeTask[0]);
        return taskFunction(docId, userId, Sorder);
    },
    koostaSorder: {
        command: `SELECT error_code, result, error_message, doc_type_id
                  FROM docs.create_new_order($2::INTEGER, (SELECT to_jsonb(row.*) FROM (SELECT $1 AS arv_id, $3 as kpv, 'SORDER' as dok) row))`, //$1 - docs.doc.id, $2 - userId
        type: "sql",
        alias: 'koostaSorder'
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

module.exports = Sorder;

'use strict';
let now = new Date();

const Andmed = {
    select: [
        {
            sql: `SELECT d.id,
                         d.status                     AS doc_status,
                         $2::INTEGER                  AS userid,
                         l1.rekvId,
                         to_char(a.kpv, 'YYYY-MM-DD') AS kpv,
                         asutus.nimetus               AS asutus,
                         l1.objektid,
                         l1.asutusid,
                         o.aadress                    AS objekt,
                         a.lepingid,
                         a.muud
                  FROM docs.doc d
                           INNER JOIN docs.moodu1 a ON a.parentId = d.id
                           INNER JOIN docs.leping1 l1 ON l1.parentid = a.lepingid
                           INNER JOIN libs.asutus AS asutus ON asutus.id = l1.asutusId
                           INNER JOIN libs.object o ON o.id = l1.objektid
                  WHERE d.id = $1`,
            sqlAsNew: `SELECT $1::INTEGER                                                       AS id,
                              $2::INTEGER                                                       AS userid,
                              NULL                                                              AS rekvId,
                              to_char(current_date,'YYYY-MM-DD')                                AS kpv,
                              NULL                                                              AS asutusid,
                              NULL::INTEGER                                                     AS objektId,
                              NULL::TEXT                                                        AS objekt,
                              NULL::TEXT                                                        AS asutus,
                              NULL::TEXT                                                        AS muud`,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
        {
            sql: `SELECT a1.id,
                         $2::INTEGER                      AS userid,
                         a1.nomid,
                         a1.kogus,
                         coalesce((SELECT kogus
                                   FROM docs.moodu2 m2
                                            INNER JOIN docs.moodu1 m1 ON m1.id = m2.parentid
                                   WHERE m2.nomid = a1.nomid
                                     AND m1.lepingid = a.lepingid
                                     AND m1.kpv < a.kpv
                                   ORDER BY m2.id DESC
                                   LIMIT 1
                                  )::NUMERIC, 0)::NUMERIC AS eel_kogus,
                         trim(n.nimetus)::VARCHAR(254)    AS nimetus,
                         a1.muud
                  FROM docs.moodu2 AS a1
                           INNER JOIN docs.moodu1 a ON a.id = a1.parentId
                           INNER JOIN docs.leping1 l1 ON l1.parentid = a.lepingid
                           INNER JOIN libs.nomenklatuur n ON n.id = a1.nomId
                  WHERE a.parentid = $1::INTEGER`,
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

    ],
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "1px", show: false},
            {id: "number", name: "Leping Nr.", width: "10%"},
            {id: "kpv", name: "Kuupaev", width: "10%"},
            {id: "asutus", name: "Asutus", width: "20%"},
            {id: "objekt", name: "Objekt", width: "20%"},
            {id: "moodu", name: "Andmed", width: "40%"},
        ],
        sqlString: `SELECT $2                           AS user_id,
                           d.id,
                           d.rekvid,
                           d.number,
                           to_char(d.kpv, 'DD.MM.YYYY') AS kpv,
                           d.asutus,
                           d.asutusid,
                           d.objekt                     AS objekt,
                           d.moodu
                    FROM cur_moodu d
                    WHERE d.rekvId = $1
                    ORDER BY d.number`,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curLepingud'
    },
    returnData: {
        row: {},
        details: [],
        relations: [],
        gridConfig: [
            {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
            {id: 'nomid', name: 'nomId', width: '0px', show: false, type: 'text', readOnly: false},
            {id: 'nimetus', name: 'Nimetus', width: '300px', show: true, readOnly: true},
            {id: 'kogus', name: 'kogus', width: '100px', show: true, type: 'number', readOnly: false},
            {id: 'eel_kogus', name: 'Eelmise kogus', width: '100px', show: true, type: 'number', readOnly: false},
        ]
    },
    saveDoc: `select docs.sp_salvesta_moodu($1, $2, $3) as id`,
    deleteDoc: `SELECT error_code, result, error_message
                FROM docs.sp_delete_moodu($1, $2)`, // $1 - userId, $2 - docId
    requiredFields: [
        {
            name: 'kpv',
            type: 'D',
            min: now.setFullYear(now.getFullYear() - 1),
            max: now.setFullYear(now.getFullYear() + 1)
        },
        {name: 'lepingid', type: 'N', min: null, max: null},
    ],

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

module.exports = Andmed;


'use strict';
let now = new Date();

const Leping = {
    selectAsLibs: `SELECT d.id, l1.number AS kood, o.aadress AS nimetus, l1.asutusid, l1.objektid, l2.noms
                   FROM docs.doc d
                            INNER JOIN docs.leping1 l1 ON d.id = l1.parentid
                            INNER JOIN (SELECT l2.parentid,
                                               json_agg(json_build_object('nom_id', to_json(nomid),
                                                                          'kood', to_json(ltrim(rtrim(n.kood))),
                                                                          'hind', to_json(l2.hind),
                                                                          'kogus', to_json(l2.kogus),
                                                                          'eel_kogus', to_json((coalesce((SELECT kogus
                                                                                                          FROM docs.moodu2 m2
                                                                                                                   INNER JOIN docs.moodu1 m1 ON m1.id = m2.parentid
                                                                                                          WHERE m2.nomid = l2.nomid
                                                                                                            AND m1.lepingid = l1.parentid
                                                                                                          ORDER BY m1.kpv DESC
                                                                                                          LIMIT 1
                                                                                                         )::NUMERIC,
                                                                                                         0)::NUMERIC))
                                                   )) AS noms
                                        FROM docs.leping2 l2
                                                 INNER JOIN libs.nomenklatuur n ON n.id = l2.nomid
                                                 INNER JOIN docs.leping1 l1 ON l1.id = l2.parentid
                                        GROUP BY l2.parentid
                   ) l2 ON l2.parentid = l1.id
                            INNER JOIN libs.asutus_user_id au ON au.asutus_id = l1.asutusid
                            INNER JOIN libs.object o ON o.id = l1.objektid
                   WHERE l1.rekvId = $1::INTEGER`, //$1 - rekvid, $2 userid

    select: [
        {
            sql: `SELECT d.id,
                         $2::INTEGER                      AS userid,
                         a.number                         AS number,
                         a.rekvId,
                         to_char(a.kpv, 'YYYY-MM-DD')     AS kpv,
                         a.asutusid,
                         a.selgitus,
                         to_char(a.tahtaeg, 'YYYY-MM-DD') AS tahtaeg,
                         a.dok,
                         a.objektid,
                         o.aadress                        AS objekt,
                         a.muud
                  FROM docs.doc d
                           INNER JOIN docs.leping1 a ON a.parentId = d.id
                           INNER JOIN libs.asutus AS asutus ON asutus.id = a.asutusId
                           INNER JOIN libs.object o ON o.id = a.objektid
                           INNER JOIN ou.userid u ON u.id = $2::INTEGER
                  WHERE d.id = $1`,
            sqlAsNew: `SELECT $1::INTEGER                                                       AS id,
                              $2::INTEGER                                                       AS userid,
                              docs.sp_get_number($1::integer, 'LEPING', year(), NULL)::VARCHAR(20) AS number,
                              NULL                                                              AS rekvId,
                              to_char(current_date,'YYYY-MM-DD')                                AS kpv,
                              NULL                                                              AS asutusid,
                              NULL::TEXT                                                        AS selgitus,
                              to_char((current_date + INTERVAL '10 years'),'YYYY-MM-DD')        AS tahtaeg,
                              NULL::TEXT                                                        AS dok,
                              NULL::INTEGER                                                     AS objektId,
                              NULL::TEXT                                                        AS objekt,
                              NULL::TEXT                                                        AS muud`,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
        {
            sql: `SELECT a1.id,
                         $2::INTEGER                   AS userid,
                         a1.nomid,
                         a1.kogus,
                         a1.hind,
                         a1.kbm,
                         a1.summa,
                         trim(n.kood)::VARCHAR(20)     AS kood,
                         trim(n.nimetus)::VARCHAR(254) AS nimetus,
                         a1.status,
                         a1.formula,
                         a1.muud
                  FROM docs.leping2 AS a1
                           INNER JOIN docs.leping1 a ON a.id = a1.parentId
                           INNER JOIN libs.nomenklatuur n ON n.id = a1.nomId
                           INNER JOIN ou.userid u ON u.id = $2::INTEGER
                  WHERE a.parentid = $1::INTEGER`,
            query: null,
            multiple: true,
            alias: 'details',
            data: []
        },

    ],
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "25px", show: false},
            {id: "number", name: "Number", width: "10%"},
            {id: "kpv", name: "Kuupaev", width: "10%"},
            {id: "asutus", name: "Asutus", width: "20%"},
            {id: "selgitus", name: "Selgitus", width: "20%"},
            {id: "objekt", name: "Objekt", width: "20%"},
            {id: "tahtaeg", name: "Tähtaeg", width: "10%"},
        ],
        sqlString: `SELECT d.id,
                           d.rekvid,
                           d.number,
                           to_char(d.kpv, 'YYYY-MM-DD')     AS kpv,
                           to_char(d.tahtaeg, 'YYYY-MM-DD') AS tahtaeg,
                           d.selgitus,
                           d.asutus,
                           d.asutusid,
                           d.objekt                         AS objekt
                    FROM cur_lepingud d
                             INNER JOIN libs.asutus_user_id au ON au.asutus_id = d.asutusid
                    WHERE d.rekvId = $1::INTEGER
                      AND au.user_id = $2::INTEGER
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
        ]
    },
    saveDoc: `select docs.sp_salvesta_leping($1, $2, $3) as id`,
    deleteDoc: `SELECT error_code, result, error_message
                FROM docs.sp_delete_leping($1, $2)`, // $1 - userId, $2 - docId
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
        {name: 'kogus', type: 'N', min: -9999999, max: 999999}
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

module.exports = Leping;


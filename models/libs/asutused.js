module.exports = {
    select: [{
        sql: `SELECT *,
                     $2::INTEGER                                     AS userid,
                     'ASUTUSED'                                      AS doc_type_id,
                     (properties ->> 'pank')::VARCHAR(20)            AS pank,
                     (properties ->> 'kmkr')::VARCHAR(20)            AS kmkr,
                     (properties ->> 'kehtivus')::DATE               AS kehtivus,
                     (properties ->> 'kehtivus')::DATE               AS valid,
                     (properties -> 'asutus_aa' -> 0 ->> 'aa')::TEXT AS aa,
                     (properties ->> 'palk_email'):: VARCHAR(254)    AS palk_email
              FROM libs.asutus
              WHERE id = $1`,
        sqlAsNew: `select $1::integer as id , $2::integer as userid, 'ASUTUSED' as doc_type_id,
            ''::text as  regkood,
            ''::text as nimetus,
            ''::text as omvorm,
            ''::text as aadress,
            ''::text as kontakt,
            ''::text as tel,
            ''::text as faks,
            ''::text as email,
            null::text as muud,
            ''::text as tp,
            0::integer as staatus,
            ''::varchar(20) as pank,
            '' :: VARCHAR(254)    AS palk_email,            
            ''::varchar(20) as kmkr,
            ''::text as mark,
            ''::TEXT AS aa`,
        query: null,
        multiple: false,
        alias: 'row',
        data: []
    },
        {
            sql: `SELECT au.id,
                         u.kasutaja AS kasutaja,
                         u.ametnik  AS nimi,
                         r.nimetus  AS rekv
                  FROM libs.asutus a
                           INNER JOIN libs.asutus_user_id au ON au.asutus_id = a.id
                           INNER JOIN ou.userid u ON u.id = au.user_id
                           INNER JOIN ou.rekv r ON r.id = u.rekvid
                  WHERE a.id = $1
                    AND r.id IN (SELECT rekvid FROM ou.userid WHERE id = $2)`, //$1 - doc_id, $2 0 userId
            query: null,
            multiple: true,
            alias: 'details',
            data: []
        },
        {
            sql: `SELECT o.id,
                         o.aadress,
                         $2 AS rekv_id
                  FROM libs.object o
                           INNER JOIN libs.object_owner oo ON oo.object_id = o.id
                           INNER JOIN libs.asutus a ON a.id = oo.asutus_id
                  WHERE a.id = $1`, //$1 - doc_id, $2 0 userId
            query: null,
            multiple: true,
            alias: 'objects',
            data: []
        },

        {
            sql: `SELECT (e.element ->> 'aa') :: VARCHAR(20) AS aa,
                         $2 :: INTEGER                       AS userid
                  FROM libs.asutus a,
                       json_array_elements(CASE
                                               WHEN (a.properties ->> 'asutus_aa') IS NULL THEN '[]'::JSON
                                               ELSE (a.properties -> 'asutus_aa') :: JSON END) AS e (element)
                  WHERE a.id = $1`, //$1 - doc_id, $2 0 userId
            query: null,
            multiple: true,
            alias: 'asutus_aa',
            data: []

        },
    ],
    selectAsLibs: `SELECT *, kehtivus AS valid, regkood AS kood, $1 AS rekv_id
                   FROM com_asutused a
                   WHERE (kehtivus IS NULL OR kehtivus >= current_date)
                   ORDER BY nimetus`, //$1 - rekvId

    libGridConfig: {
        grid: [
            {id: "id", name: "id", width: "50px", show: false},
            {id: "regkood", name: "Isikukood", width: "25%"},
            {id: "nimetus", name: "Nimi", width: "75%"}
        ]
    },
    returnData: {
        row: {},
        details: [],
        objects: [],
        gridConfig:
            [
                {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
                {id: 'kasutaja', name: 'Kasutaja tunnus', width: '30%', show: true, type: 'text', readOnly: false},
                {id: 'nimi', name: 'Kasutaja nimi', width: '40%', show: true, type: 'text', readOnly: false},
                {id: 'rekv', name: 'Asutus', width: '30%', show: true, type: 'text', readOnly: false},
            ],
        gridObjectsConfig:
            [
                {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
                {id: 'aadress', name: 'Aadress', width: '100%', show: true, type: 'text', readOnly: false},
            ],

    },
    requiredFields: [
        {name: 'regkood', type: 'C', serverValidation: 'validateIsikukood'},
        {name: 'nimetus', type: 'C'},
        {name: 'omvorm', type: 'C'}
    ],
    saveDoc: `select libs.sp_salvesta_asutus($1::json, $2::integer, $3::integer) as id`, // $1 - data json, $2 - userid, $3 - rekvid
    deleteDoc: `SELECT error_code, result, error_message
                FROM libs.sp_delete_asutus($1::INTEGER, $2::INTEGER)`, // $1 - userId, $2 - docId
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "10%", show: false},
            {id: "regkood", name: "Reg.kood", width: "30%"},
            {id: "nimetus", name: "Nimetus", width: "35%"},
            {id: "aadress", name: "Aadress", width: "35%"},
            {id: "valid", name: "Kehtivus", width: "10%", type: 'date', show: false},
        ],
        sqlString: `SELECT a.*, $1 AS rekvid, $2::INTEGER AS userId, a.kehtivus AS valid
                    FROM cur_asutused a`,     // проверка на права. $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curAsutused'
    },

    validateIsikukood: {
        command: `SELECT id
                  FROM libs.asutus
                  WHERE regkood = $1::TEXT
                  ORDER BY id DESC
                  LIMIT 1`,
        type: 'sql',
        alias: 'validateIsikukood'
    },
    print: [
        {
            view: 'asutus_register',
            params: 'id'
        },
        {
            view: 'asutus_register',
            params: 'sqlWhere'
        },
    ],
    getLog: {
        command: `SELECT ROW_NUMBER() OVER ()              AS id,
                         (ajalugu ->> 'user')::VARCHAR(20) AS kasutaja,
                         coalesce(to_char((ajalugu ->> 'created')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)         AS koostatud,
                         coalesce(to_char((ajalugu ->> 'updated')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)         AS muudatud,
                         coalesce(to_char((ajalugu ->> 'print')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)         AS prinditud,
                         coalesce(to_char((ajalugu ->> 'deleted')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)         AS kustutatud

                  FROM (
                           SELECT jsonb_array_elements('[]'::JSONB || d.ajalugu::JSONB) AS ajalugu, d.id
                           FROM libs.asutus d,
                                ou.userid u
                           WHERE d.id = $1
                             AND u.id = $2
                       ) qry
                  WHERE (ajalugu ->> 'user') IS NOT NULL`,
        type: "sql",
        alias: "getLogs"
    },

};
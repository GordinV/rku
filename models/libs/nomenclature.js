module.exports = {
    select: [{
        sql: `SELECT n.kood,
                     n.id,
                     n.nimetus,
                     n.dok::VARCHAR(20),
                     n.muud,
                     n.rekvid,
                     $2::INTEGER                                                              AS userid,
                     'NOMENCLATURE'                                                           AS doc_type_id,
                     n.uhik                                                                   AS uhik,
                     n.hind                                                                   AS hind,
                     (n.properties::JSONB ->> 'vat')::VARCHAR(20)                             AS vat,
                     (n.properties::JSONB ->> 'valid')::DATE                                  AS valid,
                     coalesce((n.properties::JSONB ->> 'algoritm')::TEXT, 'konstantne')::TEXT AS algoritm

              FROM libs.nomenklatuur n
              WHERE n.id = $1`,
        sqlAsNew: `select  $1::integer as id , $2::integer as userid, 'NOMENCLATURE' as doc_type_id,
            ''::varchar(20) as  kood,
            0::integer as rekvid,
            ''::varchar(254) as nimetus,
            'ARV'::varchar(20) as dok,
            ''::varchar(20) as uhik,
            0::numeric as hind,
            1::numeric as kogus,
            null::text as formula,
            0::integer as status,
            null::text as muud,
            null::text as properties,
            '20'::varchar(20) as vat,
            null::date as valid,
            'konstantne'::text as algoritm,                      
            null::text as tyyp`,
        query: null,
        multiple: false,
        alias: 'row',
        data: []
    },
        {
            sql: `SELECT *
                  FROM jsonb_to_recordset(
                               fnc_check_libs($2::JSON, $3::DATE, $1::INTEGER))
                           AS x (error_message TEXT)
                  WHERE error_message IS NOT NULL
            `, //$1 rekvid, $2 tunnus, $3 kuupaev
            query: null,
            multiple: true,
            alias: 'validate_libs',
            data: [],
            not_initial_load: true

        },
        {
            sql: `SELECT *
                  FROM jsonb_to_recordset(
                               get_nom_kasutus($2::INTEGER, $3::DATE,
                                               $1::INTEGER)
                           ) AS x (error_message TEXT, error_code INTEGER)
                  WHERE error_message IS NOT NULL
            `, //$1 rekvid, $2 v_nom.kood
            query: null,
            multiple: true,
            alias: 'validate_lib_usage',
            data: [],
            not_initial_load: true

        }

    ],
    selectAsLibs: `SELECT *
                   FROM com_nomenclature
                   WHERE (rekvid = $1 OR rekvid IS NULL)
                   ORDER BY kood`,
    returnData: {
        row: {}
    },
    requiredFields: [
        {name: 'kood', type: 'C'},
        {name: 'nimetus', type: 'C'}
    ],
    saveDoc: `select libs.sp_salvesta_nomenclature($1, $2, $3) as id`, // $1 - data json, $2 - userid, $3 - rekvid
    deleteDoc: `SELECT error_code, result, error_message
                FROM libs.sp_delete_nomenclature($1::INTEGER, $2::INTEGER)`, // $1 - userId, $2 - docId
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "0%", show: false},
            {id: "kood", name: "Kood", width: "25%"},
            {id: "nimetus", name: "Nimetus", width: "40%"}
        ],
        sqlString: `SELECT id,
                           coalesce(kood, '')::VARCHAR(20)     AS kood,
                           coalesce(nimetus, '')::VARCHAR(254) AS nimetus,
                           $2::INTEGER                         AS userId,
                           n.dok,
                           (n.properties ->> 'konto')::TEXT    AS konto,
                           (n.properties ->> 'tunnus')::TEXT   AS tunnus,
                           n.hind,
                           (n.properties ->> 'tyyp')::TEXT     AS tyyp,
                           (n.properties ->> 'valid')::DATE    AS valid
                    FROM libs.nomenklatuur n
                    WHERE (n.rekvId = $1 OR n.rekvid IS NULL)
                      AND n.status <> 3`,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curNomenklatuur'
    },
    print: [
        {
            view: 'noms_register',
            params: 'id'
        },
        {
            view: 'noms_register',
            params: 'sqlWhere'
        },
    ]

};

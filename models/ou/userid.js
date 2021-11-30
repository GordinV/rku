module.exports = {
    selectAsLibs: `SELECT *
                   FROM ou.cur_userid
                   WHERE rekvid = $1`, //$1 - asutuse id
    select: [
        {
            sql: `SELECT 'USERID'                                                           AS doc_type_id,
                         $2 :: INTEGER                                                      AS userid,
                         u.id,
                         u.rekvid,
                         u.kasutaja,
                         u.ametnik,
                         u.muud,
                         coalesce((u.roles ->> 'is_kasutaja') :: BOOLEAN, FALSE) :: INTEGER AS is_kasutaja,
                         coalesce((u.roles ->> 'is_admin') :: BOOLEAN, FALSE) :: INTEGER    AS is_admin,
                         coalesce((u.roles ->> 'is_juht') :: BOOLEAN, FALSE) :: INTEGER     AS is_juht,
                         coalesce((u.roles ->> 'is_raama') :: BOOLEAN, FALSE) :: INTEGER    AS is_raama,
                         (u.properties ->> 'email') :: VARCHAR(254)                         AS email,
                         (u.properties ->> 'port') :: TEXT                                  AS port,
                         (u.properties ->> 'user') :: TEXT                                  AS user,
                         (u.properties ->> 'pass') :: TEXT                                  AS pass,
                         (u.properties ->> 'smtp') :: TEXT                                  AS smtp,
                         (u.properties ->> 'earved') :: TEXT                                AS earved
                  FROM ou.userid u
                  WHERE id = $1`,
            sqlAsNew: `SELECT
                      $1 :: INTEGER         AS id,
                      $2 :: INTEGER         AS userid,
                      'USERID'             AS doc_type_id,
                      0 :: INTEGER      AS rekvid,
                      '' :: VARCHAR(20)  AS kasutaja,
                      '' :: VARCHAR(254) AS ametnik,
                      '' :: TEXT         AS muud,
                      0 :: INTEGER     AS is_kasutaja,
                      0 :: INTEGER     AS is_juht,
                      0 :: INTEGER     AS is_admin,
                      1 :: INTEGER     AS is_raama,
                      '' :: VARCHAR(254) AS email`,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
        {
            sql: `SELECT r.id, r.regkood, r.nimetus:: VARCHAR(254), r.parentid, u.id AS user_id
                  FROM ou.userid u
                           INNER JOIN ou.rekv r ON r.id = u.rekvid
                  WHERE kasutaja = $1
                    AND u.status <> 3
                    AND r.status <> 3`,
            query: null,
            multiple: true,
            alias: 'com_user_rekv',
            data: [],
            not_initial_load: true
        },
        {
            sql: `SELECT r.nimetus AS asutus, u.*, $2 AS rekvid
                  FROM ou.userid u
                           INNER JOIN ou.rekv r ON r.id = u.rekvid
                  WHERE ($1 = 0
                      OR u.id = $1)
                    AND r.status <> 3
                  ORDER BY u.last_login DESC
                          , u.id DESC;`,
            query: null,
            multiple: true,
            alias: 'get_all_users',
            data: [],
            not_initial_load: true
        },
        {
            sql: `SELECT *
                  FROM ou.get_user_data($1::TEXT, $2::INTEGER, NULL::TEXT)`, //$1 - login, $2 - rekv or null, $3 - module or null
            query: null,
            multiple: true,
            alias: 'get_last_login',
            data: [],
            not_initial_load: true

        },
        {
            sql: `SELECT au.id, a.id AS asutus_id, a.regkood, a.nimetus, a.aadress, $2 AS user_id_
                  FROM libs.asutus a
                           INNER JOIN libs.asutus_user_id au ON a.id = au.asutus_id
                  WHERE au.user_id = $1
            `, //$1 - id, $2 - user_id
            query: null,
            multiple: true,
            alias: 'details',
            data: []
        },

    ],
    returnData: {
        row: {},
        details: [],
        gridConfig: [
            {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
            {id: 'regkood', name: 'Reg.kood/ Isikukood', width: '20%', show: true, type: 'text', readOnly: false},
            {id: 'nimetus', name: 'Nimetus', width: '40%', show: true, readOnly: true},
            {id: 'aadress', name: 'Aadress', width: '50%', show: true, type: 'text', readOnly: false},
        ]

    },
    requiredFields: [
        {name: 'regkood', type: 'C'},
        {name: 'nimetus', type: 'C'}
    ],
    saveDoc: `select ou.sp_salvesta_userid($1::json, $2::integer, $3::integer) as id`, // $1 - data json, $2 - userid, $3 - rekvid
    deleteDoc: `SELECT error_code, result, error_message
                FROM ou.sp_delete_userid($1 :: INTEGER, $2 :: INTEGER)`, // $1 - userId, $2 - docId
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "10%", show: false},
            {id: "kasutaja", name: "Kasutaja tunnus", width: "25%"},
            {id: "ametnik", name: "Ametnik", width: "35%"},
            {id: "email", name: "Email", width: "35%"}
        ],
        sqlString: `SELECT $2 AS user_id,
                           u.id,
                           u.asutus::VARCHAR(254),
                           u.kasutaja::VARCHAR(254),
                           u.ametnik::VARCHAR(254),
                           u.is_admin::INTEGER,
                           u.is_kasutaja::INTEGER
                    FROM ou.cur_userid u
                    WHERE u.rekvid = $1`,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curUserid'
    },
    executeSql: [
        {
            sql: `UPDATE ou.userid
                  SET parool = $2
                  WHERE upper(kasutaja) = upper($1);`, //$1- login, $2 - password hash
            type: 'sql',
            alias: 'update_hash'
        },
        {
            sql: `UPDATE ou.userid
                  SET last_login =now()
                  WHERE id = $1;`, //$1- userId
            type: 'sql',
            alias: 'update_last_login'
        },

    ],

};

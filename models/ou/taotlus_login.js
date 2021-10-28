module.exports = {
    select: [
        {
            sql: `SELECT 'TAOTLUS_LOGIN'              AS doc_type_id,
                         $2 :: INTEGER                AS userid,
                         l.id,
                         to_char(l.kpv, 'YYYY-MM-DD') AS kpv,
                         l.kasutaja,
                         l.nimi,
                         l.muud,
                         l.parool,
                         l.aadress,
                         l.email,
                         l.tel,
                         d.status                     AS doc_status
                  FROM ou.taotlus_login l
                           INNER JOIN docs.doc d ON d.id = l.parentid
                  WHERE parentid = $1`,
            sqlAsNew: `SELECT
                      $1 :: INTEGER         AS id,
                      $2 :: INTEGER         AS userid,
                      current_date::date as kpv,
                      'TAOTLUS_LOGIN'             AS doc_type_id,
                      null :: text  AS kasutaja,
                      null :: text AS nimi,
                      null :: text         AS aadress,
                      null :: text         AS muud,
                      null :: text         AS tel,
                      0                     AS doc_status,
                      null :: text AS email`,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
    ],
    returnData: {
        row: {},
    },
    saveDoc: `select ou.sp_salvesta_taotlus_login($1::json, $2::integer, $3::integer) as id`, // $1 - data json, $2 - userid, $3 - rekvid
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "10%", show: false},
            {id: "kasutaja", name: "Kasutaja tunnus", width: "20%"},
            {id: "nimi", name: "Nimi", width: "30%"},
            {id: "aadress", name: "Aadress", width: "20%"},
            {id: "email", name: "Email", width: "20%"},
            {id: "staatus", name: "Staatus", width: "10%", default: 'Uus'},
        ],
        sqlString: `SELECT $2                       AS user_id,
                           $1                       AS rekv_id,
                           u.id,
                           u.kasutaja,
                           u.nimi,
                           u.aadress,
                           u.email,
                           CASE
                               WHEN u.status = 1 THEN 'Uus'
                               WHEN u.status = 2 THEN 'Kinnitatud'
                               WHEN u.status = 3 THEN 'Kustutatud'
                               ELSE 'Määramata' END AS staatus
                    FROM ou.taotlus_login u`,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'cur_taotlus_login'
    },
    kinnitaTaotlus: {
        command: `SELECT error_code, result, error_message, result AS doc_id, 'TAOTLUS_LOGIN' AS docTypeId
                  FROM ou.kinnita_taotlus($2::INTEGER, $1::INTEGER)`, // $1 - userId, $2 - docId
        type: "sql",
        alias: 'kinnitaTaotlus'
    },
    bpm: [
        {
            id: 1,
            name: 'Kinnita taotlus',
            task: 'kinnitaTaotlus',
            action: 'kinnitaTaotlus',
            type: 'manual',
            hideDate: false,
            showKogus: false,
            actualStep: false,

        }],


};

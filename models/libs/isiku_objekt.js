module.exports = {
    select: [{
        sql: `SELECT o.id,
                     $2 AS userId,
                     o.rekvid,
                     o.aadress,
                     o.muud
              FROM libs.object o
              WHERE o.id = $1`,
        sqlAsNew: `select  $1::integer as id , 
            $2::integer as userid,
            null::integer as rekvid, 
            null::text as aadress
            null::text as muud`,
        query: null,
        multiple: false,
        alias: 'row',
        data: []
    }, {
        sql: `SELECT oo.id,
                     a.nimetus,
                     a.email,
                     a.tel
              FROM libs.object o
                       INNER JOIN libs.object_owner oo ON oo.object_id = o.id
                       INNER JOIN libs.asutus a ON a.id = oo.asutus_id
                       INNER JOIN libs.asutus_user_id au ON au.asutus_id = a.id
              WHERE o.id = $1
                AND au.user_id = $2`,
        query: null,
        multiple: true,
        alias: 'details',
        data: []

    }
    ],
    returnData: {
        row: {},
        details: [],
        gridConfig:
            [
                {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
                {id: 'nimetus', name: 'Nimi', width: '40%', show: true, type: 'text', readOnly: false},
                {id: 'email', name: 'Email', width: '30%', show: true, type: 'text', readOnly: false},
                {id: 'tel', name: 'Telefon', width: '30%', show: true, type: 'text', readOnly: false},
            ],
    },
    requiredFields: [
        {name: 'aadress', type: 'C'},
    ],
    saveDoc: `select libs.sp_salvesta_objekt($1, $2, $3) as id`, // $1 - data json, $2 - userid, $3 - rekvid
    deleteDoc: `SELECT error_code, result, error_message
                FROM libs.sp_delete_library($1::INTEGER, $2::INTEGER)`, // $1 - userId, $2 - docId
    selectAsLibs: `SELECT *
                   FROM com_objekt l
                   WHERE (l.rekvId = $1 OR l.rekvid IS NULL)
                   ORDER BY kood`,
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "10%", show: false},
            {id: "aadress", name: "Aadress", width: "50%"},
            {id: "muud", name: "Märkused", width: "50%"},
        ],
        sqlString: `SELECT $2::INTEGER AS userId,
                           o.*
                    FROM libs.object o
                             INNER JOIN libs.object_owner oo ON oo.object_id = o.id
                             INNER JOIN libs.asutus_user_id au ON au.asutus_id = oo.asutus_id
                    WHERE o.rekvid = $1::INTEGER
                      AND au.user_id = $2::INTEGER
                      AND o.status <> 3`,     // проверка на права. $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curObjekt'
    }

};
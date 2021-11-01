module.exports = {
    select: [{
        sql: `SELECT d.id,
                     $2::INTEGER                       AS userid,
                     d.rekvid,
                     to_char(r.alg_kpv, 'YYYY-MM-DD')  AS alg_kpv,
                     to_char(r.lopp_kpv, 'YYYY-MM-DD') AS lopp_kpv,
                     r.nimetus,
                     r.link,
                     r.asutusid                        AS asutusid,
                     a.nimetus                         AS asutus,
                     r.muud
              FROM docs.doc d
                       INNER JOIN docs.rekl r ON d.id = r.parentid
                       INNER JOIN libs.asutus a ON a.id = r.asutusid
              WHERE d.id = $1`,
        sqlAsNew: `select  
        $1::integer as id , 
        $2::integer as userid, 
        null::integer as rekvid,
                     to_char(current_date, 'YYYY-MM-DD')  AS alg_kpv,
                     to_char(current_date + interval '1 month', 'YYYY-MM-DD') AS lopp_kpv,
        null::text as nimetus,
        null::text as asutus,
        null::integer as asutusid,
        null::text as link,
            null::text as module`,
        query: null,
        multiple: false,
        alias: 'row',
        data: []
    }],
    returnData: {
        row: {}
    },
    requiredFields: [
        {name: 'alg_kpv', type: 'D'},
        {name: 'lopp_kpv', type: 'D'},
        {name: 'asutusid', type: 'I'},
        {name: 'nimetus', type: 'C'},
        {name: 'link', type: 'C'}
    ],
    saveDoc: `select docs.sp_salvesta_rekl($1, $2, $3) as id`, // $1 - data json, $2 - userid, $3 - rekvid
    deleteDoc: `SELECT error_code, result, error_message
                FROM docs.sp_delete_rekl($1::INTEGER, $2::INTEGER)`, // $1 - userId, $2 - docId

    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "10%", show: false},
            {id: "alg_kpv", name: "Alg. kuupäev", width: "15%", type: "date", interval: true},
            {id: "lopp_kpv", name: "Lõpp. kuupäev", width: "15%", type: "date", interval: true},
            {id: "asutus", name: "Reklaamiandja", width: "30%"},
            {id: "nimetus", name: "Nimetus", width: "40%"},

        ],
        sqlString: `         SELECT d.id,
                                    to_char(r.alg_kpv, 'DD.MM.YYYY') :: TEXT  AS alg_kpv,
                                    to_char(r.lopp_kpv, 'DD.MM.YYYY') :: TEXT AS lopp_kpv,
                                    r.asutusid,
                                    a.nimetus                                 AS asutus,
                                    r.nimetus                                 AS nimetus,
                                    r.link                                    AS link,
                                    $1::INTEGER                               AS rekvid,
                                    $2::INTEGER                               AS userId,
                                    rekv.nimetus                              AS rekv,
                                    d.lastupdate::date,
                                    r.last_shown::date
                             FROM docs.doc d
                                      INNER JOIN docs.rekl r ON d.id = r.parentid
                                      INNER JOIN libs.asutus a ON a.id = r.asutusid
                                      INNER JOIN ou.rekv rekv ON rekv.id = d.rekvid
                             WHERE d.status <> 3
                             ORDER BY d.lastupdate DESC`,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'cur_rekl'
    },
    print: [
        {
            view: 'tunnus',
            params: 'id',
            converter: function (data) {
//преобразует дату к формату yyyy-mm-dd
                data.map(row => {
                    if (row.valid) {
                        row.valid = row.valid.toISOString().slice(0, 10);
                    }
                    return row;
                });
                return data;
            }
        },
        {
            view: 'tunnus',
            params: 'sqlWhere',
            converter: function (data) {
//преобразует дату к формату yyyy-mm-dd
                data.map(row => {
                    if (row.valid) {
                        row.valid = row.valid.toISOString().slice(0, 10);
                    }
                    return row;
                });
                return data;
            }
        },
    ]

};


module.exports = {
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "10%", show: false},
            {id: "dokument", name: "Dokument", width: "25%"},
            {id: "kpv", name: "Kuupäev", width: "15%", type: "date", interval: true},
            {id: "objekt", name: "Objekt", width: "50%"}
        ],
        sqlString: `SELECT *,
                           $1::INTEGER AS rekvid,
                           $2::INTEGER AS userId
                    FROM (
                             SELECT d.id,
                                    l.kood::TEXT                          AS doc_type_id,
                                    l.nimetus                             AS dokument,
                                    to_char(l1.kpv, 'DD.MM.YYYY') :: TEXT AS kpv,
                                    a.nimetus                             AS asutus,
                                    o.aadress                             AS objekt,
                                    d.lastupdate
                             FROM docs.doc d
                                      INNER JOIN docs.leping1 l1 ON d.id = l1.parentid
                                      INNER JOIN libs.asutus a ON a.id = l1.asutusid
                                      INNER JOIN libs.library l ON l.id = d.doc_type_id
                                      INNER JOIN libs.object o ON o.id = l1.objektid
                                      INNER JOIN libs.asutus_user_id au ON au.asutus_id = l1.asutusid
                             WHERE (d.rekvid IS NULL OR d.rekvid = $1)
                               AND au.user_id = $2::INTEGER
                               AND d.status <> 3
                             UNION ALL
                             SELECT d.id,
                                    l.kood::TEXT                          AS doc_type_id,
                                    l.nimetus                             AS dokument,
                                    to_char(l1.kpv, 'DD.MM.YYYY') :: TEXT AS kpv,
                                    a.nimetus                             AS asutus,
                                    o.aadress                             AS objekt,
                                    d.lastupdate
                             FROM docs.doc d
                                      INNER JOIN docs.arv l1 ON d.id = l1.parentid
                                      INNER JOIN libs.asutus a ON a.id = l1.asutusid
                                      INNER JOIN libs.library l ON l.id = d.doc_type_id
                                      INNER JOIN libs.object o ON o.id = l1.objektid
                                      INNER JOIN libs.asutus_user_id au ON au.asutus_id = l1.asutusid
                             WHERE (d.rekvid IS NULL OR d.rekvid = $1)
                               AND au.user_id = $2::INTEGER
                               AND d.status <> 3
                         ) qry
                    ORDER BY lastupdate DESC
        `,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'cur_teatised'
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


module.exports = {
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "1%", show: false},
            {id: "dokument", name: "Dokument", width: "20%"},
            {id: "kpv", name: "Kuupäev", width: "20%", type: "date", interval: true},
            {id: "asutus", name: "Korteriomanik", width: "30%"},
            {id: "objekt", name: "Objekt", width: "30%"}
        ],
        sqlString: `SELECT d.id,
                           l.kood::TEXT                         AS doc_type_id,
                           l.nimetus                            AS dokument,
                           to_char(l1.kpv, 'DD.MM.YYYY') :: TEXT AS kpv,
                           a.nimetus                            AS asutus,
                           o.aadress                            AS objekt,
                           $1::INTEGER                          AS rekvid,
                           $2::INTEGER                          AS userId
                    FROM docs.doc d
                             INNER JOIN docs.leping1 l1 ON d.id = l1.parentid
                             INNER JOIN libs.asutus a ON a.id = l1.asutusid
                             INNER JOIN libs.library l ON l.id = d.doc_type_id
                             INNER JOIN libs.object o ON o.id = l1.objektid
                    WHERE (d.rekvid IS NULL OR d.rekvid = $1)
                      AND d.status <> 3
                    ORDER BY d.lastupdate DESC
        `,     //  $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'cur_docs'
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


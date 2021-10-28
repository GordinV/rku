module.exports = {
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "10%", show: false},
            {id: "dokument", name: "Dokument", width: "25%"},
            {id: "kpv", name: "Kuupäev", width: "15%", type: "date", interval: true},
            {id: "saatja", name: "Saatja", width: "30%"},
            {id: "staatus", name: "Staatus", width: "20%", default: 'Uus'}
        ],
        sqlString: `SELECT d.id,
                           l.kood::TEXT                          AS doc_type_id,
                           l.nimetus                             AS dokument,
                           to_char(tl.kpv, 'DD.MM.YYYY') :: TEXT AS kpv,
                           tl.nimi                               AS saatja,
                           tl.aadress,
                           CASE
                               WHEN tl.status = 1 THEN 'Uus'
                               WHEN tl.status = 2 THEN 'Kinnitatud'
                               WHEN tl.status = 3 THEN 'Tagastatud'
                               ELSE
                                   'Määramata' END               AS staatus,
                           $1::INTEGER                           AS rekvid,
                           $2::INTEGER                           AS userId
                    FROM docs.doc d
                             INNER JOIN ou.taotlus_login tl ON d.id = tl.parentid
                             INNER JOIN libs.library l ON l.id = d.doc_type_id
                    WHERE (d.rekvid IS NULL OR d.rekvid = $1)
                      AND d.status <> 3
                    ORDER BY d.lastupdate DESC
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


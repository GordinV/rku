module.exports = {
    grid: {
        gridConfiguration: [
            {id: "kpv", name: "Kuupäev", width: "7%", type: "date", interval: true},
            {id: "number", name: "Arve nr", width: "7%"},
            {id: "kood", name: "Kood", width: "7%"},
            {id: "hind", name: "Hind", width: "7%", type: "number", "interval": true},
            {id: "uhik", name: "Ühik", width: "5%"},
            {id: "kogus", name: "Kogus", width: "7%", type: "number", "interval": true},
            {id: "summa", name: "Summa", width: "10%", type: "number", "interval": true},
            {id: "select", name: "Valitud", width: "5%", show: false, type: 'boolean', hideFilter: true}

        ],
        sqlString: ` SELECT liik.nimetus                       AS liik,
                            sum(a1.summa) OVER ()              AS summa_kokku,
                            to_char(a.kpv, 'DD.MM.YYYY')       AS kpv,
                            a.number::TEXT,
                            n.kood,
                            n.uhik,
                            a1.hind,
                            a1.kogus,
                            a1.summa,
                            r.nimetus::TEXT                    AS asutus,
                            $2                                 AS user_id,
                            TRUE                               AS select,
                            d.id
                     FROM docs.doc d
                              INNER JOIN docs.arv a ON d.id = a.parentid
                              INNER JOIN docs.arv1 a1 ON a1.parentid = a.id
                              INNER JOIN libs.nomenklatuur n ON a1.nomid = n.id
                              INNER JOIN ou.rekv r ON r.id = d.rekvid
                              LEFT OUTER JOIN libs.library liik ON r.properties ->> 'liik' = liik.kood
                         AND liik.status <> 3

                     WHERE d.status <> 3
                       AND a.rekvid = $1
                       AND ((a.properties ->> 'ettemaksu_period') IS NULL
                         OR a.properties ->> 'tyyp' = 'ETTEMAKS')
                     ORDER BY kpv, a.number, r.nimetus
        `,     // $1 - rekvid, $3 - kond
        params: '',
        alias: 'arved_koodi_jargi_report'
    },
    print: [
        {
            view: 'arved_koodi_jargi_register',
            params: 'sqlWhere',
            converter: function (data) {
                let summa_kokku = 0;
                let row_id = 0;
                data.forEach(row => {
                    summa_kokku = summa_kokku + Number(row.summa);
                });

                return data.map(row => {
                    row_id++;
                    row.summa_kokku = summa_kokku;
                    row.row_id = row_id;
                    return row;
                })
            }

        },
    ],

};

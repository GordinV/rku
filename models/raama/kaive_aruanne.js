module.exports = {
    grid: {
        gridConfiguration: [
            {id: "period", name: "Period", width: "5%", show: false, type: "date", interval: true},
            {id: "nimi", name: "Nimi", width: "15%"},
            {id: "objekt", name: "Objekt", width: "25%", show: true},
            {id: "alg_saldo", name: "Alg.saldo", width: "10%", type: "number", interval: true},
            {id: "arvestatud", name: "Arvestatud", width: "10%", type: "number", interval: true},
            {id: "laekumised", name: "Laekumised", width: "10%", type: "number", interval: true},
            {id: "tagastused", name: "Tagastused", width: "10%", type: "number", interval: true},
            {id: "jaak", name: "Võlg", width: "10%", type: "number", interval: true},
        ],
        sqlString: `SELECT count(*) OVER ()                                                   AS rows_total,
                           qryReport.id,
                           qryReport.period,
                           qryReport.nimi,
                           isikukood,
                           o.aadress as objekt,
                           coalesce(alg_saldo, 0)::NUMERIC(14, 4)                             AS alg_saldo,
                           coalesce(arvestatud, 0)::NUMERIC(14, 4)                            AS arvestatud,
                           coalesce(laekumised, 0)::NUMERIC(14, 4)                            AS laekumised,
                           coalesce(tagastused, 0)::NUMERIC(14, 4)                            AS tagastused,
                           coalesce(jaak, 0)::NUMERIC(14, 4)                                  AS jaak,
                           $2                                                                 AS user_id
                    FROM docs.kaive_aruanne($1::INTEGER, $3, $4) qryReport
                             LEFT OUTER JOIN libs.object_owner oo ON oo.asutus_id = qryReport.isik_id
                             LEFT OUTER JOIN libs.object o ON oo.object_id = o.id

        `,     // $1 - rekvid, $3 - alg_kpv, $4 - lopp_kpv
        params: ['rekvid', 'userid', 'period_start', 'period_end'],
        totals: ` sum(alg_saldo) over() as alg_saldo_total,
                sum(arvestatud) over() as arvestatud_total,
                sum(laekumised) over() as laekumised_total,
                sum(tagastused) over() as tagastused_total,
                sum(jaak) over() as jaak_total `,
        alias: 'kaive_aruanne_report'
    },
    print: [
        {
            view: 'kaive_aruanne_register',
            params: 'sqlWhere',
            group: 'asutus',
            converter: function (data) {
                let alg_saldo_kokku = 0;
                let arvestatud_kokku = 0;
                let laekumised_kokku = 0;
                let tagastused_kokku = 0;
                let row_id = 0;
                let groupedData = {};
                data.forEach(row => {
                    alg_saldo_kokku = Number(alg_saldo_kokku) + Number(row.alg_saldo);
                    arvestatud_kokku = Number(arvestatud_kokku) + Number(row.arvestatud);
                    laekumised_kokku = Number(laekumised_kokku) + Number(row.laekumised);
                    tagastused_kokku = Number(tagastused_kokku) + Number(row.tagastused);
                });

                return data.map(row => {
                    row_id++;
                    row.alg_saldo_kokku = alg_saldo_kokku;
                    row.arvestatud_kokku = arvestatud_kokku;
                    row.laekumised_kokku = laekumised_kokku;
                    row.tagastused_kokku = tagastused_kokku;
                    row.row_id = row_id;
                    return row;
                })
            }
        },
    ],

};

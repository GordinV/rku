module.exports = {
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "0", show: false},
            {id: "asutus", name: "Asutus", width: "30%"},
            {id: "number", name: "Dok nr", width: "7%"},
            {id: "kpv", name: "Kuupäev", width: "7%", type: "date", interval: true},
            {id: "summa", name: "Arvestatud", width: "10%", type: "number", "interval": true},
            {id: "tasutud", name: "Laekumised", width: "10%", type: "number", "interval": true},
            {id: "jaak", name: "Dok. jääk", width: "10%", type: "number", "interval": true},
        ],
        sqlString: `SELECT row_number() OVER ()         AS id,
                           sum(summa) OVER ()           AS arvestatud_total,
                           sum(tasutud) OVER ()         AS laekumised_total,
                           to_char(a.kpv, 'DD.MM.YYYY') AS kpv,
                           a.asutus,
                           a.number,
                           a.summa,
                           a.tasutud,
                           a.jaak
                    FROM docs.arve_kokkuvote($1::INTEGER, $2::DATE, $3::DATE) a
                    ORDER BY asutus, kpv
        `,     // $1 - rekvid, $3 - kond
        params: ['rekvid', 'kpv_start', 'kpv_end'],
        alias: 'arved_kokkuvote'
    },
    print: [
        {
            view: 'arve_kokkuvote',
            params: 'sqlWhere',
            group: 'asutus',
            converter: function (data) {
                let summa_kokku = 0;
                let tasud_kokku = 0;
                data.forEach(row => {
                    summa_kokku = summa_kokku + Number(row.summa);
                    tasud_kokku = tasud_kokku + Number(row.tasutud);
                });

                return data.map(row => {
                    row.summa_kokku = summa_kokku;
                    row.tasud_kokku = tasud_kokku;
                    return row;
                })
            }

        },
    ],

};

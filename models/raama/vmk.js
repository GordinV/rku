'use strict';

let now = new Date();

const Vmk = {
    select: [
        {
            sql: `SELECT d.id,
                         d.docs_ids,
                         d.bpm,
                         trim(l.nimetus)                           AS doc,
                         trim(l.kood)                              AS doc_type_id,
                         k.number                                  AS number,
                         to_char(k.maksepaev, 'YYYY-MM-DD')        AS maksepaev,
                         k.viitenr,
                         k.aaid                                    AS aa_id,
                         aa.pank                                   AS pank,
                         trim(aa.arve)::VARCHAR(20)                AS omaArve,
                         k.rekvId,
                         to_char(k.kpv, 'YYYY-MM-DD')              AS kpv,
                         k.selg,
                         k.muud,
                         k.opt,
                         k.arvid,
                         k.aaid,
                         ('Number:' || arv.number :: TEXT || ' Kuupäev:' || arv.kpv :: TEXT || ' Jääk:' ||
                          arv.jaak :: TEXT)                        AS arvnr,
                         (SELECT sum(summa)
                          FROM docs.mk1
                          WHERE parentid = k.id)                   AS summa,
                         (d.history -> 0 ->> 'user')::VARCHAR(120) AS koostaja,
                         k.dokid
                  FROM docs.doc d
                           INNER JOIN docs.mk k ON k.parentId = d.id
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                           LEFT OUTER JOIN libs.library l ON l.id = d.doc_type_id
                           LEFT OUTER JOIN ou.aa AS aa ON k.aaid = aa.Id
                           LEFT OUTER JOIN docs.arv AS arv ON k.arvid = arv.Id
                  WHERE d.id = $1`,
            sqlAsNew: `SELECT $1 :: INTEGER                                  AS id,
                              $2 :: INTEGER                                  AS userid,
                              NULL                                           AS bpm,
                              'VMK'                                          AS doc_type_id,
                              docs.sp_get_number(u.rekvid::INTEGER, 'VMK'::TEXT,
                                                 date_part('year', current_date)::INTEGER,
                                                 NULL::INTEGER)::VARCHAR(20) AS number,
                              now() :: DATE                                  AS maksepaev,
                              0                                              AS aaid,
                              1                                              AS pank,
                              trim('')::VARCHAR(20)                          AS omaarve,
                              NULL::INTEGER                                  AS rekvId,
                              now() :: DATE                                  AS kpv,
                              NULL::VARCHAR(120)                             AS viitenr,
                              NULL::TEXT                                     AS selg,
                              NULL::TEXT                                     AS muud,
                              1                                              AS opt,
                              NULL::VARCHAR(20)                              AS regkood,
                              NULL::VARCHAR(254)                             AS asutus,
                              NULL::INTEGER                                  AS arvid,
                              NULL::VARCHAR(20)                              AS arvnr,
                              0::NUMERIC(12, 2)                              AS summa,
                              NULL                                           AS dokid
                       FROM (SELECT *
                             FROM ou.userid u
                             WHERE u.id = $2 :: INTEGER) AS u
                       WHERE u.id = $2 :: INTEGER`,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
        {
            sql: `SELECT $2 :: INTEGER                 AS userid,
                         trim(n.kood)::VARCHAR(20)     AS kood,
                         trim(n.nimetus)::VARCHAR(254) AS nimetus,
                         trim(a.nimetus)::VARCHAR(254) AS asutus,
                         trim(a.aadress)               AS aadress,
                         k.parentid                    AS parent_id,
                         k1.*
                  FROM docs.mk1 AS k1
                           INNER JOIN docs.mk k ON k.id = k1.parentId
                           INNER JOIN libs.nomenklatuur n ON n.id = k1.nomid
                           INNER JOIN libs.asutus a ON a.id = k1.asutusid
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                  WHERE k.parentid = $1`,
            query: null,
            multiple: true,
            alias: 'details',
            data: []
        },
        {
            sql: `SELECT rd.id,
                         $2 :: INTEGER   AS userid,
                         trim(l.kood)    AS doc_type,
                         trim(l.nimetus) AS name
                  FROM docs.doc d
                           LEFT OUTER JOIN docs.doc rd ON rd.id IN (SELECT unnest(d.docs_ids))
                           LEFT OUTER JOIN libs.library l ON rd.doc_type_id = l.id
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                  WHERE d.id = $1`,
            query: null,
            multiple: true,
            alias: 'relations',
            data: []
        }

    ],
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "1px", show: false},
            {id: "kpv", name: "Kuupäev", width: "15%"},
            {id: "number", name: "Number", width: "10%"},
            {id: "asutus", name: "Maksja", width: "30%"},
            {id: "asutusid", name: "asutusid", width: "1px", show: false},
            {id: "nomid", name: "nomid", width: "1px", show: false},
            {id: "aa", name: "Arveldus arve", width: "20%"},
            {id: "viitenr", name: "Viite number", width: "10%"},
            {id: "maksepaev", name: "Maksepäev", width: "15%"},
            {id: "kreedit", name: "Summa", width: "15%"},
            {id: "maksepaev", name: "Maksepäev", width: "15%"},

        ],
        sqlString: `SELECT mk.id,
                           $2                                  AS user_id,
                           to_char(mk.kpv, 'DD.MM.YYYY')       AS kpv,
                           mk.selg,
                           mk.nimetus                          AS asutus,
                           mk.kood,
                           mk.rekvid,
                           mk.deebet,
                           mk.kreedit,
                           mk.number,
                           mk.journalid,
                           mk.aa,
                           mk.opt,
                           mk.regkood,
                           0                                   AS valitud,
                           to_char(mk.maksepaev, 'DD.MM.YYYY') AS maksepaev
                    FROM cur_pank mk
                    WHERE mk.rekvId = $1
                    and kreedit <> 0`,     // $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curMk'
    },
    returnData: {
        row: {},
        details: [],
        gridConfig: [
            {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
            {id: 'nimetus', name: 'Nimetus', width: '100px', show: true, type: 'text', readOnly: false},
            {id: "nomid", name: "nomid", width: "200px", show: false},
            {id: 'asutus', name: 'Maksja', width: '200px', show: true, type: 'text', readOnly: false},
            {id: 'aa', name: 'Arveldus arve', width: '150px', show: true, type: 'text', readOnly: false},
            {id: 'summa', name: 'Summa', width: '100px', show: true, type: 'number', readOnly: false},
            {id: 'konto', name: 'Korr.konto', width: '100px', show: true, type: 'text', readOnly: false},
            {id: 'tunnus', name: 'Tunnus', width: '100px', show: true, type: 'text', readOnly: false},
            {id: 'proj', name: 'Projekt', width: '100px', show: true, type: 'text', readOnly: false}
        ]
    },
    saveDoc: `select docs.sp_salvesta_mk($1::json, $2::integer, $3::integer) as id`,
    deleteDoc: `SELECT error_code, result, error_message
                FROM docs.sp_delete_mk($1::INTEGER, $2::INTEGER)`, // $1 - userId, $2 - docId
    requiredFields: [
        {
            name: 'kpv',
            type: 'D',
            min: now.setFullYear(now.getFullYear() - 1),
            max: now.setFullYear(now.getFullYear() + 1)
        }
    ],
    bpm: [],
    executeTask: (task, docId, userId) => {
        // выполнит задачу, переданную в параметре

        let executeTask = task;
        if (executeTask.length == 0) {
            executeTask = ['start'];
        }

        let taskFunction = eval(executeTask[0]);
        return taskFunction(docId, userId, Vmk);
    },
    getLog: {
        command: `SELECT ROW_NUMBER() OVER ()                                                                        AS id,
                         (ajalugu ->> 'user')::VARCHAR(20)                                                           AS kasutaja,
                         coalesce(to_char((ajalugu ->> 'created')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS koostatud,
                         coalesce(to_char((ajalugu ->> 'updated')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS muudatud,
                         coalesce(to_char((ajalugu ->> 'print')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS prinditud,
                         coalesce(to_char((ajalugu ->> 'email')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'), '')::VARCHAR(20) AS
                                                                                                                        email,
                         coalesce(to_char((ajalugu ->> 'earve')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS earve,
                         coalesce(to_char((ajalugu ->> 'deleted')::TIMESTAMP, 'DD.MM.YYYY HH.MM.SS'),
                                  '')::VARCHAR(20)                                                                   AS kustutatud
                  FROM (
                           SELECT jsonb_array_elements(history) AS ajalugu, d.id, d.rekvid
                           FROM docs.doc d,
                                ou.userid u
                           WHERE d.id = $1
                             AND u.id = $2
                       ) qry`,
        type: "sql",
        alias: "getLogs"
    },


};

module.exports = Vmk;

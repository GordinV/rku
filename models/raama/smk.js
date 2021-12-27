'use strict';

let now = new Date();

const Smk = {
    select: [
        {
            sql: `SELECT d.id,
                         d.docs_ids,
                         trim(l.nimetus)                           AS doc,
                         trim(l.kood)                              AS doc_type_id,
                         k.number                                  AS number,
                         to_char(k.maksepaev, 'YYYY-MM-DD')        AS maksepaev,
                         to_char(k.maksepaev, 'DD.MM.YYYY')::TEXT  AS maksepaev_print,
                         k.viitenr,
                         k.aaid                                    AS aa_id,
                         aa.pank                                   AS pank,
                         trim(aa.arve)::VARCHAR(20)                AS omaArve,
                         k.rekvId,
                         to_char(k.kpv, 'YYYY-MM-DD')              AS kpv,
                         to_char(k.kpv, 'DD.MM.YYYY')::TEXT        AS kpv_print,
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
                         k.doklausid,
                         (d.history -> 0 ->> 'user')::VARCHAR(120) AS koostaja,
                         coalesce(k.jaak, 0):: NUMERIC             AS jaak

                  FROM docs.doc d
                           INNER JOIN docs.mk k ON k.parentId = d.id
                           INNER JOIN ou.userid u ON u.id = $2 :: INTEGER
                           LEFT OUTER JOIN libs.library l ON l.id = d.doc_type_id
                           LEFT OUTER JOIN ou.aa AS aa ON k.aaid = aa.Id
                           LEFT OUTER JOIN docs.arv AS arv ON k.arvid = arv.Id
                  WHERE d.id = $1`,
            sqlAsNew: `SELECT $1 :: INTEGER                                  AS id,
                              $2 :: INTEGER                                  AS userid,
                              'SMK'                                          AS doc_type_id,
                              docs.sp_get_number(u.rekvid::INTEGER, 'SMK'::TEXT,
                                                 date_part('year', current_date)::INTEGER,
                                                 NULL::INTEGER)::VARCHAR(20) AS number,
                              to_char(current_date, 'YYYY-MM-DD')            AS maksepaev,
                              0                                              AS aaid,
                              trim('')::VARCHAR(20)                          AS pank,
                              NULL::INTEGER                                  AS rekvId,
                              to_char(current_date, 'YYYY-MM-DD')            AS kpv,
                              NULL::VARCHAR(120)                             AS viitenr,
                              NULL::TEXT                                     AS selg,
                              NULL::TEXT                                     AS muud,
                              2                                              AS opt,
                              NULL::VARCHAR(20)                              AS regkood,
                              NULL::VARCHAR(254)                             AS asutus,
                              NULL::INTEGER                                  AS arvid,
                              NULL::VARCHAR(20)                              AS arvnr,
                              0::NUMERIC(12, 2)                              AS summa,
                              0                                              AS doklausid
                       FROM ou.userid u
                       WHERE u.id = $2 :: INTEGER
            `,
            query: null,
            multiple: false,
            alias: 'row',
            data: []
        },
        {
            sql: `SELECT $2 :: INTEGER   AS userid,
                         trim(n.kood)    AS kood,
                         trim(n.nimetus) AS nimetus,
                         trim(a.nimetus) AS asutus,
                         trim(a.aadress) AS aadress,
                         k.parentid      AS parent_id,
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
            sql: `SELECT rd.id, $2::INTEGER AS userid, trim(l.kood) AS doc_type, trim(l.nimetus) AS name
                  FROM docs.doc d
                           LEFT OUTER JOIN docs.doc rd ON rd.id IN (SELECT unnest(d.docs_ids))
                           LEFT OUTER JOIN libs.library l ON rd.doc_type_id = l.id
                           INNER JOIN ou.userid u ON u.id = $2::INTEGER
                  WHERE d.id = $1
                    AND d.status <> 3`,
            query: null,
            multiple: true,
            alias: 'relations',
            data: []
        }

    ],
    grid: {
        gridConfiguration: [
            {id: "id", name: "id", width: "1px", show: false},
            {id: "kpv", name: "Kuupäev", width: "15%", interval: true, type: 'date'},
            {id: "number", name: "Number", width: "10%"},
            {id: "asutus", name: "Maksja", width: "30%"},
            {id: "aa", name: "Arveldus arve", width: "20%"},
            {id: "viitenr", name: "Viite number", width: "10%"},
            {id: "maksepaev", name: "Maksepäev", width: "15%", interval: true, type: 'date'},
            {id: "deebet", name: "Summa", width: "15%", interval: true, type: 'numeric'},

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
                      AND deebet <> 0`,     // $1 всегда ид учреждения $2 - всегда ид пользователя
        params: '',
        alias: 'curMk'
    },

    returnData: {
        row: {},
        details: [],
        gridConfig: [
            {id: 'id', name: 'id', width: '0px', show: false, type: 'text', readOnly: true},
            {id: 'nimetus', name: 'Nimetus', width: '100px', show: true, type: 'text', readOnly: false},
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
        },
        {
            name: 'aaid',
            type: 'I',
        }

    ],
    bpm: [
        {
            id: 0,
            name: 'Koosta tagasimakse',
            task: 'KoostaTagasimakse',
            action: 'KoostaTagasimakse',
            type: 'manual',
            showDate: true,
            showKogus: false,
            actualStep: false,
        },
    ],
    KoostaTagasimakse: {
        command: `SELECT error_code, result, error_message, doc_type_id
                  FROM docs.create_return_mk($2::INTEGER, (SELECT to_jsonb(row.*)
                                                           FROM (SELECT $1 AS mk_id, $3::DATE AS maksepaev) row))`, //$1 - docs.doc.id, $2 - userId, $3 - maksepaev
        type: "sql",
        alias: 'KoostaTagasimakse'
    },


    executeTask: (task, docId, userId) => {
        // выполнит задачу, переданную в параметре

        let executeTask = task;
        if (executeTask.length == 0) {
            executeTask = ['start'];
        }

        let taskFunction = eval(executeTask[0]);
        return taskFunction(docId, userId);
    },
    getLog: {
        command: `SELECT ROW_NUMBER() OVER ()                                                                        AS id,
                         (ajalugu ->> 'user')::VARCHAR(20)                                                           AS kasutaja,
                         coalesce(to_char((ajalugu ->> 'created')::TIMESTAMP, 'DD.MM.YYYY HH.MI.SS'),
                                  '')::VARCHAR(20)                                                                   AS koostatud,
                         coalesce(to_char((ajalugu ->> 'updated')::TIMESTAMP, 'DD.MM.YYYY HH.MI.SS'),
                                  '')::VARCHAR(20)                                                                   AS muudatud,
                         coalesce(to_char((ajalugu ->> 'print')::TIMESTAMP, 'DD.MM.YYYY HH.MI.SS'),
                                  '')::VARCHAR(20)                                                                   AS prinditud,
                         coalesce(to_char((ajalugu ->> 'email')::TIMESTAMP, 'DD.MM.YYYY HH.MI.SS'), '')::VARCHAR(20) AS
                                                                                                                        email,
                         coalesce(to_char((ajalugu ->> 'earve')::TIMESTAMP, 'DD.MM.YYYY HH.MI.SS'),
                                  '')::VARCHAR(20)                                                                   AS earve,
                         coalesce(to_char((ajalugu ->> 'deleted')::TIMESTAMP, 'DD.MM.YYYY HH.MI.SS'),
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
    print: [
        {
            view: 'smk_kaart',
            params: 'id',
            register: `UPDATE docs.doc
                       SET history = history ||
                                     (SELECT row_to_json(row)
                                      FROM (SELECT now()                                                AS print,
                                                   (SELECT kasutaja FROM ou.userid WHERE id = $2)::TEXT AS user) row)::JSONB
                       WHERE id = $1`
        },
        {
            view: 'smk_register',
            params: 'sqlWhere'
        },
    ],


};

module.exports = Smk;

const start = (docId, userId) => {
    // реализует старт БП документа
    const DOC_STATUS = 1, // устанавливаем активный статус для документа
        DocDataObject = require('./../documents'),
        SQL_UPDATE = 'UPDATE docs.doc SET status = $1, bpm = $2, history = $4 WHERE id = $3',
        SQL_SELECT_DOC = Smk.select[0].sql;

    let bpm = setBpmStatuses(0, userId), // выставим актуальный статус для следующего процесса
        history = {user: userId, updated: Date.now()};

    // выполнить запрос и вернуть промис
    return DocDataObject.executeSqlQueryPromise(SQL_UPDATE, [DOC_STATUS, JSON.stringify(bpm), docId, JSON.stringify(history)]);

};

const setBpmStatuses = (actualStepIndex, userId) => {
// собираем данные на на статус документа, правим данные БП документа
    // 1. установить на actualStep = false
    // 2. задать статус документу
    // 3. выставить стутус задаче (пока только finished)
    // 4. если есть следующий шаг, то выставить там actualStep = true, статус задачи opened


    try {
        var bpm = Smk.bpm, // нельзя использовать let из - за использования try {}
            nextStep = bpm[actualStepIndex].nextStep,
            executors = bpm[actualStepIndex].actors || [];

        if (!executors || executors.length == 0) {
            // если исполнители не заданы, то добавляем автора
            executors.push({
                id: userId,
                name: 'AUTHOR',
                role: 'AUTHOR'
            })
        }

        bpm[actualStepIndex].data = [{execution: Date.now(), executor: userId, vars: null}];
        bpm[actualStepIndex].status = 'finished';  // 3. выставить стутус задаче (пока только finished)
        bpm[actualStepIndex].actualStatus = false;  // 1. установить на actualStep = false
        bpm[actualStepIndex].actors = executors;  // установить список акторов

        // выставим флаг на следующий щаг
        bpm = bpm.map(stepData => {
            if (stepData.step === nextStep) {
                // 4. если есть следующий шаг, то выставить там actualStep = true, статус задачи opened
                stepData.actualStep = true;
                stepData.status = 'opened';
            }
            return stepData;
        });

    } catch (e) {
        console.error('try error', e);
    }
    return bpm;

};

DROP FUNCTION IF EXISTS docs.create_return_mk(INTEGER, JSONB);

CREATE OR REPLACE FUNCTION docs.create_return_mk(IN user_id INTEGER,
                                                 IN params JSONB,
                                                 OUT error_code INTEGER,
                                                 OUT result INTEGER,
                                                 OUT doc_type_id TEXT,
                                                 OUT error_message TEXT)
    RETURNS RECORD AS
$BODY$
DECLARE
    l_mk_id      INTEGER = params ->> 'mk_id';
    l_maksepaev  DATE    = params ->> 'maksepaev';
    mk_id        INTEGER;
    l_dok        TEXT    = 'VMK';
    l_dokprop_id INTEGER;
    l_rekvId     INTEGER = (SELECT rekvid
                            FROM ou.userid
                            WHERE id = user_id
                            LIMIT 1);
    v_mk         RECORD ;
    v_mk1        RECORD ;
    json_mk1     JSON;

    v_params     RECORD;
    json_object  JSON;
BEGIN
    doc_type_id = 'VMK';

    SELECT * INTO v_mk
    FROM docs.mk
    WHERE parentid = l_mk_id
    LIMIT 1;

    SELECT 0          AS id,
           nomid      AS nomid,
           asutusid   AS asutusid,
           summa      AS summa,
           aa :: TEXT AS aa,
           konto      AS konto,
           tunnus,
           proj
           INTO v_mk1
    FROM docs.mk1
    WHERE parentid = v_mk.id
    LIMIT 1;


    -- если есть счет, то собираем строку с классфикаторами оттуда

    json_mk1 = array_to_json((SELECT array_agg(row_to_json(v_mk1))));

    SELECT 0                                         AS id,
           l_dokprop_id                              AS doklausid,
           v_mk.aaid                                 AS aa_id,
           NULL                                      AS arvid,
           1                                         AS opt,-- возврат платежа
           v_mk.viitenr                              AS viitenr,
           NULL                                      AS number,
           l_maksepaev                               AS kpv,
           l_maksepaev                               AS maksepaev,
           'Tagasimakse ' || coalesce(v_mk.selg, '') AS selg,
           NULL                                      AS muud,
           json_mk1                                  AS "gridData"
           INTO v_params;

    SELECT row_to_json(row) INTO json_object
    FROM (SELECT 0        AS id,
                 v_params AS data) row;

   SELECT docs.sp_salvesta_mk(json_object :: JSON, user_id, l_rekvId) INTO mk_id;

    RETURN;
EXCEPTION
    WHEN OTHERS
        THEN
            RAISE NOTICE 'error % %', SQLERRM, SQLSTATE;
            error_code = 1;
            error_message = SQLERRM;
            result = 0;
            RETURN;
END;
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.create_return_mk(INTEGER, JSONB) TO db;


/*
SELECT docs.create_return_mk(28, '{"mk_id":2308496, "maksepaev":"20210531"}')

*/
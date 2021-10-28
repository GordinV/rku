DROP FUNCTION IF EXISTS docs.create_new_order(INTEGER, JSONB);

CREATE OR REPLACE FUNCTION docs.create_new_order(IN user_id INTEGER,
                                                 IN params JSONB,
                                                 OUT error_code INTEGER,
                                                 OUT result INTEGER,
                                                 OUT doc_type_id TEXT,
                                                 OUT error_message TEXT)
    RETURNS RECORD AS
$BODY$
DECLARE
    l_arv_id     INTEGER = params ->> 'arv_id';
    l_dok        TEXT    = coalesce((params ->> 'dok') :: TEXT, 'SORDER');
    korder_id    INTEGER;
    v_arv        RECORD;
    json_object  JSONB;
    v_params     RECORD;
    json_korder1 JSONB;
    l_kassa_id   INTEGER;

    DOC_TYPE_ID  TEXT    = 'SORDER';
    KASSA_ID     INTEGER = 0;
    l_dokprop_id INTEGER;


BEGIN

    PERFORM docs.sp_update_arv_jaak(l_arv_id);


    -- выборка из "документа"
    SELECT d.rekvid     AS rekv_id,
           a.*,
           isik.nimetus AS nimi,
           isik.aadress
    INTO v_arv
    FROM docs.doc d
             INNER JOIN docs.arv a ON a.parentid = d.id
             INNER JOIN libs.asutus isik ON isik.id = a.asutusid
    WHERE d.id = l_arv_id;

    IF l_arv_id IS NULL OR v_arv.id IS NULL OR empty(l_arv_id)
    THEN
        error_message = 'Arve puudub või vale parametrid';
        error_code = 6;
        result = 0;
        RETURN;
    END IF;


    IF v_arv.jaak <= 0
    THEN
        result = 0;
        error_code = 0;
        error_message = 'Arve jaak <= 0';
        RETURN;
    END IF;

    -- создаем параметры для платежки

    l_kassa_id = (SELECT id
                  FROM ou.aa
                  WHERE kassa = KASSA_ID
                    AND parentid = v_arv.rekv_id
                  ORDER BY default_ DESC
                  LIMIT 1);

    json_korder1 = array_to_json((SELECT array_agg(row_to_json(m1.*))
                                  FROM (SELECT 0          AS id,
                                               (SELECT id
                                                FROM libs.nomenklatuur n
                                                WHERE rekvid = v_arv.rekvid
                                                  AND dok IN (l_dok)
                                                ORDER BY id DESC
                                                LIMIT 1)  AS nomid,
                                               a1.konto,
                                               a1.tunnus,
                                               a1.proj,
                                               v_arv.jaak AS summa
                                        FROM docs.arv1 a1
                                        WHERE a1.parentid = v_arv.id
                                        ORDER BY summa DESC
                                        LIMIT 1
                                       ) AS m1
    ));

    SELECT 0              AS id,
           l_dokprop_id   AS doklausid,
           v_arv.asutusid AS asutusid,
           v_arv.nimi     AS nimi,
           v_arv.aadress,
           l_kassa_id     AS kassa_id,
           v_arv.parentid AS arvid,
           CASE
               WHEN v_arv.liik = 0
                   THEN 1
               ELSE 2 END AS TYYP,
           v_arv.jaak     AS summa,
           current_date   AS kpv,
           NULL           AS selg,
           NULL           AS muud,
           json_korder1   AS "gridData"
    INTO v_params;

    SELECT row_to_json(row)
    INTO json_object
    FROM (SELECT 0        AS id,
                 v_params AS data) row;

    SELECT docs.sp_salvesta_korder(json_object :: JSON, user_id, v_arv.rekvid) INTO korder_id;

    doc_type_id = CASE WHEN v_arv.liik = 0 THEN 'SORDER' ELSE 'VORDER' END;

    IF korder_id IS NOT NULL AND korder_id > 0
    THEN
        result = korder_id;
        RAISE NOTICE 'order saved korder_id %', korder_id;
    ELSE
        result = 0;
        error_message = 'Dokumendi koostamise viga';
        error_code = 1;
    END IF;

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

GRANT EXECUTE ON FUNCTION docs.create_new_order(INTEGER, JSONB) TO db;


/*
SELECT error_code, result, error_message, doc_type_id
                  FROM docs.create_new_order(4::INTEGER, (SELECT to_jsonb(row.*) FROM (SELECT 34 AS arv_id, current_date as kpv, 'SORDER' as dok) row))`, //$1 - docs.doc.id, $2 - userId


SELECT docs.create_new_order(70, '{"arv_id":1616785,"dok":"SORDER"}')
*/
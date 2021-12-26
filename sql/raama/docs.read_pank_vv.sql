DROP FUNCTION IF EXISTS docs.read_pank_vv(IN user_id INTEGER, IN TIMESTAMP);
DROP FUNCTION IF EXISTS docs.read_pank_vv(IN user_id INTEGER, IN TEXT);


CREATE OR REPLACE FUNCTION docs.read_pank_vv(IN user_id INTEGER, IN l_timestamp TEXT,
                                               OUT error_code INTEGER,
                                               OUT result INTEGER,
                                               OUT error_message TEXT,
                                               OUT data JSONB)
    RETURNS RECORD AS
$BODY$
DECLARE
    l_mk_id          INTEGER;
    v_arv            RECORD;
    json_object      JSONB;
    v_pank_vv        RECORD;
    l_rekvid         INTEGER;
    l_error          TEXT; -- извещение о том, что пошло не так
    l_count          INTEGER = 0;
    l_count_kokku    INTEGER = 0;
    l_db_konto       TEXT    = '113'; -- дебетовая (банк) сторона
    l_dokprop_id     INTEGER;
    l_target_user_id INTEGER = user_id;
    l_user_kood      TEXT    = (SELECT kasutaja
                                FROM ou.userid
                                WHERE id = user_id
                                LIMIT 1);
    l_maksja_id      INTEGER;
    l_new_viitenr    TEXT;
    l_mk_number      TEXT;
    l_message        TEXT;
    l_error_code     INTEGER = 0;
    l_viitenr        TEXT;
    l_kas_vigane     BOOLEAN = FALSE;
BEGIN
    -- ищем платежи
    FOR v_pank_vv IN
        SELECT *
        FROM docs.pank_vv v
        WHERE timestamp::TIMESTAMP = l_timestamp::TIMESTAMP
          AND (doc_id IS NULL OR doc_id = 0)
          AND isikukood IS NOT NULL
        ORDER BY kpv, id
        LOOP
            l_message = 'Tehingu nr.: ' || ltrim(rtrim(v_pank_vv.pank_id)) ||
                        ',Maksja:' || ltrim(rtrim(v_pank_vv.maksja));
            l_viitenr = v_pank_vv.viitenumber;


            -- ишем плательшика
            SELECT row_to_json(row)
            INTO json_object
            FROM (SELECT v_pank_vv.isikukood AS regkood,
                         v_pank_vv.maksja    AS nimetus,
                         v_pank_vv.iban      AS aa,
                         'ISIK'::TEXT        AS omvorm) row;

            l_maksja_id = (SELECT a.result FROM libs.create_new_asutus(user_id, json_object::JSONB) a);

            -- ищем ид конфигурации контировки
            IF v_pank_vv.pank = 'EEUHEE2X' OR v_pank_vv.pank = '401'
            THEN
                -- seb
                l_db_konto = '1132';
            ELSEIF v_pank_vv.pank = 'HABAEE2X' OR v_pank_vv.pank = '767'
            THEN
                -- swed
                l_db_konto = '1131';
            END IF;

            l_dokprop_id = (SELECT dp.id
                            FROM libs.dokprop dp
                                     INNER JOIN libs.library l ON l.id = dp.parentid
                            WHERE dp.rekvid = l_rekvid
                              AND (dp.details ->> 'konto')::TEXT = l_db_konto::TEXT
                            ORDER BY dp.id DESC
                            LIMIT 1
            );

            IF l_dokprop_id IS NULL
            THEN
                l_dokprop_id = (SELECT id
                                FROM com_dokprop l
                                WHERE (l.rekvId = l_rekvId OR l.rekvid IS NULL)
                                  AND kood = 'SMK'
                                ORDER BY id DESC
                                LIMIT 1
                );
            END IF;

            -- обнуляем счетчик найденных счетов
            l_count = 0;

            l_mk_id = NULL;
            IF coalesce(l_maksja_id, 0) > 0
            THEN

                -- создаем параметры для расчета платежкм
                SELECT row_to_json(row)
                INTO json_object
                FROM (SELECT l_maksja_id      AS maksja_id,
                             l_dokprop_id     AS dokprop_id,
                             l_new_viitenr    AS viitenumber,
                             v_pank_vv.selg   AS selg,
                             v_pank_vv.number AS number,
                             v_pank_vv.kpv    AS kpv,
                             v_pank_vv.aa     AS aa,
                             v_pank_vv.iban   AS maksja_arve,
                             v_pank_vv.summa  AS summa) row;

                -- создаем платежку
                SELECT fnc.result, fnc.error_message
                INTO l_mk_id, l_error
                FROM docs.create_new_mk(l_target_user_id, json_object) fnc;
            END IF;

            IF l_mk_id IS NOT NULL AND l_mk_id > 0
            THEN
                l_count = l_count + 1;
                l_count_kokku = l_count_kokku + 1;
                l_kas_vigane = FALSE;
                l_message = coalesce(l_message, '') || ', MK ' || ltrim(rtrim(v_pank_vv.number)) || ' koostatud';

                -- lausend
                PERFORM docs.gen_lausend_smk(l_mk_id, l_target_user_id);

                -- сохраняем полученную информаци.
                UPDATE docs.pank_vv v
                SET doc_id   = l_mk_id,
                    markused = l_error
                WHERE id = v_pank_vv.id;

            ELSE
                l_mk_number = '';
            END IF;

            -- report
            json_object = to_jsonb(row.*)
                          FROM (
                                   SELECT l_mk_id               AS doc_id,
                                          l_message             AS error_message,
                                          l_viitenr             AS viitenr,
                                          l_kas_vigane          AS kas_vigane,
                                          l_error_code::INTEGER AS error_code
                               ) row;
            data = coalesce(data, '[]'::JSONB) || json_object::JSONB;
        END LOOP;
    result = l_count_kokku;
    error_code = l_error_code;
    error_message = l_message;

    RETURN;
EXCEPTION
    WHEN OTHERS
        THEN
            RAISE NOTICE 'error % %', SQLERRM, SQLSTATE;
            error_code = 1;
            error_message = SQLERRM;
            result = 0;
            json_object = to_jsonb(row.*)
                          FROM (
                                   SELECT NULL::INTEGER                     AS doc_id,
                                          l_message || ',' || error_message AS error_message,
                                          l_viitenr                         AS viitenr,
                                          TRUE                              AS kas_vigane,
                                          1::INTEGER                        AS error_code
                               ) row;
            data = coalesce(data, '[]'::JSONB) || json_object::JSONB;

            RETURN;
END;
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.read_pank_vv(IN user_id INTEGER, IN TEXT) TO db;


/*
select * from lapsed.pank_vv

SELECT lapsed.read_pank_vv(70, '2020-02-15 10:36:32.748115')


       SELECT *
        FROM lapsed.pank_vv v
        WHERE timestamp::TIMESTAMP = '2020-02-15 10:36:32.748115'::TIMESTAMP
          AND (doc_id IS NULL OR doc_id = 0)
        ORDER BY kpv, id


doc_aa_id 11,  user_rekvid 63
[2019-12-10 20:52:57] [00000] l_tasu_summa 7.0000, l_kpv 2019-12-10
[2019-12-10 20:52:57] [00000] l_tasu_summa 7.0000, l_kpv 2019-12-10
[2019-12-10 20:52:57] [00000] l_mk_id 1616718, l_error <NULL>, v_arv.id 1616712
[2019-12-10 20:52:57] [00000] l_tasu_jaak 0.00
*/

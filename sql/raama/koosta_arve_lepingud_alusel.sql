-- Function: docs.sp_delete_mk(integer, integer)

DROP FUNCTION IF EXISTS docs.koosta_arve_lepingu_alusel(INTEGER, INTEGER, DATE);

CREATE OR REPLACE FUNCTION docs.koosta_arve_lepingu_alusel(IN user_id INTEGER,
                                                           IN l_leping_id INTEGER,
                                                           IN l_kpv DATE DEFAULT current_date,
                                                           OUT error_code INTEGER,
                                                           OUT result INTEGER,
                                                           OUT doc_type_id TEXT,
                                                           OUT error_message TEXT,
                                                           OUT viitenr TEXT)
    RETURNS RECORD AS
$BODY$

DECLARE
    l_rekvid        INTEGER = (SELECT rekvid
                               FROM ou.userid u
                               WHERE id = user_id
                               LIMIT 1);

    l_asutus_id     INTEGER = (SELECT asutusid
                               FROM docs.leping1 l1
                                        INNER JOIN libs.asutus a ON a.id = l1.asutusid
                               WHERE l1.parentid = l_leping_id);
    l_doklausend_id INTEGER;
    l_liik          INTEGER = 0;
    json_object     JSONB;
    l_json_arve     JSON;
    json_arvrea     JSONB   = '[]';
    json_arvread    JSONB   = '[]';

    l_arv_id        INTEGER = 0;
    l_status        INTEGER;
    l_number        TEXT;
    l_arve_summa    NUMERIC = 0;
    i               INTEGER = 1;
    v_maksja        RECORD;
    jsonb_print     JSONB   = '[]';
    l_aa            TEXT    = (SELECT arve
                               FROM ou.aa
                               WHERE parentid IN (SELECT rekvid FROM ou.userid WHERE id = user_id)
                                 AND kassa = 1
                               ORDER BY default_ DESC
                               LIMIT 1);

    l_db_konto      TEXT    = '103000'; -- согдасно описанию отдела культуры
    l_arve_kogus    NUMERIC = 0; -- для проверки кол-ва услуг в счете
    v_leping        RECORD;
    l_moodu_ids     INTEGER[];
    v_moodu         RECORD;
    v_objekt        RECORD;

BEGIN

    IF l_asutus_id IS NULL
    THEN
        -- контр-анет не найден, выходим
        result = 0;
        error_message = 'Puudub kontragent';
        error_code = 1;
        RETURN;
    END IF;
    -- ищем ид конфигурации контировки

    l_doklausend_id = (SELECT dp.id
                       FROM libs.dokprop dp
                                INNER JOIN libs.library l ON l.id = dp.parentid
                       WHERE dp.rekvid = l_rekvid
                         AND (dp.details ->> 'konto')::TEXT = l_db_konto::TEXT
                         AND l.kood = 'ARV'
                       ORDER BY dp.id DESC
                       LIMIT 1
    );

    doc_type_id = 'ARV';

    -- ищем аналогичный счет в периоде
    -- критерий
    -- 1. получатель
    -- 2. ребенок
    -- 3. период
    -- 4. услуги из списка табеля

    SELECT l1.objektid, l1.number
    INTO v_objekt
    FROM docs.leping1 l1
    WHERE l1.parentid = l_leping_id
    LIMIT 1;

    -- читаем договора и создаем детали счета
    FOR v_leping IN
        SELECT l1.number,
               l2.nomid,
               coalesce(moodu.kogus, l2.kogus)                         AS kogus,
               l2.hind                                                 AS hind,
               l2.hind * coalesce(moodu.kogus, l2.kogus)               AS summa,
               coalesce((n.properties ->> 'vat')::NUMERIC, 0)::NUMERIC AS vat,
               d.id                                                    AS leping_id,
               moodu.moodu_id
        FROM docs.doc d
                 INNER JOIN docs.leping1 l1 ON d.id = l1.parentid
                 INNER JOIN docs.leping2 l2 ON l1.id = l2.parentid
                 INNER JOIN libs.nomenklatuur n ON n.id = l2.nomid
                 LEFT OUTER JOIN (
            SELECT m1.lepingid,
                   m2.nomid,
                   m2.kogus -
                   coalesce((SELECT kogus
                             FROM docs.moodu2 mm2
                                      INNER JOIN docs.moodu1 mm1 ON mm1.id = mm2.parentid
                             WHERE mm2.nomid = m2.nomid
                               AND mm1.lepingid = m1.lepingid
                               AND mm1.kpv < m1.kpv
                             ORDER BY mm2.id DESC
                             LIMIT 1
                            )::NUMERIC, 0)::NUMERIC AS kogus,
                   d.id                             AS moodu_id
            FROM docs.doc d
                     INNER JOIN docs.moodu1 m1 ON d.id = m1.parentid
                     INNER JOIN docs.moodu2 m2 ON m2.parentid = m1.id
            WHERE d.status = 1 -- не расписанные показания
        ) moodu ON moodu.lepingid = l1.parentid
        WHERE d.id = l_leping_id
        LOOP
            -- формируем строку
            json_arvrea = '[]'::JSONB || (SELECT row_to_json(row)
                                          FROM (SELECT v_leping.nomid                                         AS nomid,
                                                       v_leping.kogus                                         AS kogus,
                                                       v_leping.hind                                          AS hind,
                                                       v_leping.summa                                         AS kbmta,
                                                       v_leping.summa * (v_leping.vat / 100)                  AS kbm,
                                                       v_leping.summa * (v_leping.vat / 100) + v_leping.summa AS summa,
                                                       ''                                                     AS muud
                                               ) row) :: JSONB;

            json_arvread = json_arvread || json_arvrea;
            -- calc arve summa
            l_arve_summa = l_arve_summa + v_leping.summa;

            i = i + 1;

            IF v_leping.moodu_id IS NOT NULL
            THEN
                l_moodu_ids = array_append(l_moodu_ids, v_leping.moodu_id);
            END IF;
        END LOOP;


    -- создаем параметры
    l_json_arve = (SELECT to_json(row)
                   FROM (SELECT coalesce(l_arv_id, 0)                         AS id,
                                l_number                                      AS number,
                                l_doklausend_id                               AS doklausid,
                                l_liik                                        AS liik,
                                l_kpv                                         AS kpv,
                                l_kpv + 15                                    AS tahtaeg,
                                l_asutus_id                                   AS asutusid,
                                l_aa                                          AS aa,
                                'Arve, lepingu number ' || v_objekt.number || ' alusel ' ||
                                date_part('month', l_kpv)::TEXT || '/' ||
                                date_part('year', l_kpv)::TEXT || ' kuu eest' AS lisa,
                                v_objekt.objektid,
                                json_arvread                                  AS "gridData") row);


    IF (jsonb_array_length(json_arvread) > 0)
    THEN

        -- подготавливаем параметры для создания счета
        SELECT row_to_json(row)
        INTO json_object
        FROM (SELECT coalesce(l_arv_id, 0) AS id, l_json_arve AS data) row;


        -- check for arve summa
/*    IF l_arve_summa < 0
    THEN
        result = 0;
        error_message = 'Dokumendi summa = 0';
        error_code = 1;
        RETURN;
    ELSE
*/

        IF l_arve_summa <> 0
        THEN
            SELECT docs.sp_salvesta_arv(json_object :: JSON, user_id, l_rekvid) INTO l_arv_id;

        END IF;
    ELSE
        l_arv_id = NULL;
        result = 0;
        error_code = 1;
        error_message = 'Kehtiv teenused ei leidnud';
        RETURN;
    END IF;


    -- проверка

    IF l_arv_id IS NOT NULL AND l_arv_id > 0
    THEN
        -- меняем статус измерений, добавляем ссылку
        UPDATE docs.doc
        SET status   = 2,
            docs_ids = array_append(docs_ids, l_arv_id)
        WHERE id IN (
            SELECT unnest(l_moodu_ids)
        );

        -- добавляем ссылку на измерения в счет
        UPDATE docs.doc
        SET docs_ids = docs_ids || l_moodu_ids
        WHERE id = l_arv_id;


/*        IF l_arve_summa > 0
        THEN
            -- контируем
            PERFORM docs.gen_lausend_arv(l_arv_id, user_id);
        END IF;
*/
        error_message = 'Leping, arveId:' ||
                        coalesce(l_arv_id, 0)::TEXT;

        result = l_arv_id;
    ELSE
        error_code = 1;
        error_message =
                'Dokumendi koostamise viga';

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
END ;
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.koosta_arve_lepingu_alusel(INTEGER, INTEGER, DATE) TO db;


/*
select lapsed.koosta_arve_taabeli_alusel(70, 47, '2019-11-30')
 */


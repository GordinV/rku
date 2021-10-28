--
-- PostgreSQL database dump
--

-- Dumped from database version 14.0
-- Dumped by pg_dump version 14.0

-- Started on 2021-10-28 22:22:25

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 41491)
-- Name: docs; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA docs;


ALTER SCHEMA docs OWNER TO postgres;

--
-- TOC entry 4 (class 2615 OID 40975)
-- Name: libs; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA libs;


ALTER SCHEMA libs OWNER TO postgres;

--
-- TOC entry 7 (class 2615 OID 32776)
-- Name: ou; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ou;


ALTER SCHEMA ou OWNER TO postgres;

--
-- TOC entry 317 (class 1255 OID 180335)
-- Name: check_arv_jaak(integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.check_arv_jaak(tnid integer, user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_arv RECORD;
BEGIN
    error_code = 0;
    result = 0;
    raise notice 'start';
    FOR v_arv IN
        SELECT d.id, a.jaak, a.tasud
        FROM docs.doc d
                 INNER JOIN docs.arv a ON a.parentid = d.id
        WHERE d.rekvid IN (SELECT rekvid FROM ou.userid WHERE id = user_id)
          AND a.jaak > 0
          AND a.tasud IS NOT NULL
          AND a.tasud <= CURRENT_DATE
          AND d.id = CASE WHEN tnId IS NOT NULL THEN tnId ELSE D.id END

        LOOP
            -- update arv jaak
            PERFORM docs.sp_update_arv_jaak(v_arv.id);
            result = result + 1;

        END LOOP;
    RETURN;
EXCEPTION
    WHEN OTHERS
        THEN
            error_code = 1;
            error_message = SQLERRM;
            RAISE NOTICE 'error % %', SQLERRM, SQLSTATE;
            RETURN;

END;
$$;


ALTER FUNCTION docs.check_arv_jaak(tnid integer, user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 308 (class 1255 OID 172732)
-- Name: create_new_mk(integer, jsonb); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.create_new_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
    l_arv_id     INTEGER        = params ->> 'arv_id';
    l_dok        TEXT           = coalesce((params ->> 'dok') :: TEXT, 'MK');
    l_summa      NUMERIC(12, 2) = params ->> 'summa';
    l_dokprop_id INTEGER        = params ->> 'dokprop_id';
    l_viitenr    TEXT           = params ->> 'viitenumber';
    l_number     TEXT           = params ->> 'number';
    l_kpv        DATE           = params ->> 'kpv';
    l_maksepaev  DATE           = params ->> 'maksepaev';
    l_selg       TEXT           = params ->> 'selg';
    l_asutus_id  INTEGER        = params ->> 'maksja_id';
    l_aa         TEXT           = params ->> 'maksja_arve';
    l_asutus_aa  TEXT           = params ->> 'aa';
    mk_id        INTEGER;
    v_arv        RECORD;
    v_mk1        RECORD;
    json_object  JSONB;
    v_params     RECORD;
    json_mk1     JSONB;
    l_pank_id    INTEGER;
    l_opt        INTEGER;
    l_rekvId     INTEGER        = (SELECT rekvid
                                   FROM ou.userid
                                   WHERE id = user_id);
    l_nom_id     INTEGER;
BEGIN


    SELECT a.*,
           coalesce((a.properties ->> 'viitenr')::TEXT, '')::VARCHAR(120) AS viitenr
    INTO v_arv
    FROM docs.doc d
             INNER JOIN docs.arv a ON a.parentid = d.id
    WHERE d.id = l_arv_id;

    doc_type_id = CASE WHEN v_arv.liik = 0 OR v_arv.id IS NULL THEN 'SMK' ELSE 'VMK' END;

    -- maksepaev
    IF l_maksepaev IS NULL
    THEN
        IF l_arv_id IS NOT NULL AND doc_type_id = 'VMK'
        THEN
            l_maksepaev = v_arv.tahtaeg;
        ELSE
            l_maksepaev = l_kpv;
        END IF;
    END IF;

    -- viitenr
    IF l_viitenr IS NULL AND v_arv.viitenr IS NOT NULL AND NOT empty(v_arv.viitenr)
    THEN
        l_viitenr = v_arv.viitenr;
    END IF;

    -- добавим пояснение
    IF l_selg IS NULL AND l_arv_id IS NOT NULL
    THEN
        l_selg = 'Arve nr.' || ltrim(rtrim(v_arv.number))::TEXT;
    END IF;

    l_opt = (CASE
                 WHEN v_arv.liik = 0 OR v_arv.id IS NULL
                     THEN 2 -- если счет доходный, то мк на поступление средств, иначе расзодное поручение
                 ELSE 1 END);

    IF l_summa IS NULL
    THEN
        l_summa = v_arv.jaak;
        IF v_arv.jaak IS NULL OR v_arv.jaak = 0
        THEN
            l_summa = v_arv.summa - (SELECT sum(summa) FROM docs.arvtasu WHERE doc_arv_id = l_arv_id AND status <> 3);
        END IF;
    END IF;

    -- если счет имеет обратное сальдо , то меняем тип на противоположный
    IF v_arv.id IS NOT NULL AND v_arv.jaak < 0
    THEN
        l_opt = CASE WHEN l_opt = 1 THEN 2 ELSE 1 END;
        l_summa = coalesce(l_summa, -1 * v_arv.jaak);
    END IF;

    IF coalesce(l_summa, 0) <= 0
    THEN
        -- платеж равен нулю
        error_message = 'Makse summa <= 0';
        RETURN;
    END IF;

    IF (l_asutus_id IS NULL AND v_arv.id IS NULL)
    THEN
        -- платильщик не идентифицирован
        error_message = 'Maksja puudub';
        RETURN;

    END IF;

    IF l_asutus_id IS NULL
    THEN
        l_asutus_id = v_arv.asutusid;
    END IF;

    -- создаем параметры для платежки

    -- ищем расчетный счет учреждения
    IF l_asutus_aa IS NOT NULL
    THEN
        l_pank_id = (SELECT id
                     FROM ou.aa aa
                     WHERE kassa = 1
                       AND parentid = l_rekvId
                       AND aa.arve::TEXT = l_asutus_aa::TEXT
                     ORDER BY default_ DESC
                     LIMIT 1);

    END IF;

    l_pank_id = CASE
                    WHEN l_pank_id IS NULL THEN (SELECT id
                                                 FROM ou.aa
                                                 WHERE kassa = 1
                                                   AND parentid = l_rekvId
                                                 ORDER BY default_ DESC
                                                 LIMIT 1)
                    ELSE l_pank_id END;

    l_nom_id = (SELECT id
                FROM libs.nomenklatuur n
                WHERE rekvid = l_rekvId
                  AND dok IN (l_dok, doc_type_id)
                ORDER BY id DESC
                LIMIT 1);
    IF (l_nom_id IS NULL)
    THEN
        INSERT INTO libs.nomenklatuur (rekvid, dok, kood, nimetus)
        VALUES (l_rekvId, doc_type_id, doc_type_id, 'Maksekorraldus') RETURNING id INTO l_nom_id;
    END IF;

    l_aa = CASE
               WHEN l_aa IS NULL THEN (COALESCE((
                                                    SELECT (e.element ->> 'aa') :: VARCHAR(20) AS aa
                                                    FROM libs.asutus a,
                                                         json_array_elements(CASE
                                                                                 WHEN (a.properties ->> 'asutus_aa') IS NULL
                                                                                     THEN '[]'::JSON
                                                                                 ELSE (a.properties -> 'asutus_aa') :: JSON END) AS e (ELEMENT)
                                                    WHERE a.id = l_asutus_id
                                                    LIMIT 1
                                                ), ''))
               ELSE l_aa END;

    IF v_arv.id IS NOT NULL
    THEN
        -- если есть счет, то собираем строку с классфикаторами оттуда
        SELECT 0                                                          AS id,
               l_nom_id                                                   AS nomid,
               l_asutus_id                                                AS asutusid,
               CASE WHEN l_summa IS NULL THEN v_arv.jaak ELSE l_summa END AS summa,
               l_aa :: TEXT                                               AS aa,
               a1.tunnus,
               a1.proj
        FROM docs.arv1 a1
        WHERE a1.
                  parentid = v_arv.id
        LIMIT 1
        INTO v_mk1;

    ELSE
        SELECT 0           AS id,
               l_nom_id    AS nomid,
               l_asutus_id AS asutusid,
               l_summa     AS summa,
               l_aa        AS aa,
               '103000'    AS konto
        INTO v_mk1;
    END IF;


    json_mk1 = array_to_json((SELECT array_agg(row_to_json(v_mk1))));

    SELECT 0              AS id,
           l_dokprop_id   AS doklausid,
           l_pank_id      AS aa_id,
           v_arv.parentid AS arvid,
           l_opt          AS opt,
           l_viitenr      AS viitenr,
           l_number       AS number,
           l_kpv          AS kpv,
           l_maksepaev    AS maksepaev,
           l_selg         AS selg,
           NULL           AS muud,
           json_mk1       AS "gridData"
    INTO v_params;

    SELECT row_to_json(row)
    INTO json_object
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
END ;
$$;


ALTER FUNCTION docs.create_new_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 327 (class 1255 OID 180350)
-- Name: create_new_order(integer, jsonb); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.create_new_order(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION docs.create_new_order(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 294 (class 1255 OID 106596)
-- Name: create_number_sequence(integer, text, boolean); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.create_number_sequence(l_rekvid integer, l_dok text, l_found_last_num boolean DEFAULT true) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    l_sequence_name TEXT = lower(l_dok) || '_' || l_rekvid::TEXT || '_number';
    l_sql           TEXT;
    l_number        TEXT;
    l_result        INTEGER;
    l_last_id       INTEGER;
BEGIN
    -- sequence name
    -- check if exists sequencetbl
    IF NOT EXISTS(
            SELECT 1 FROM pg_class WHERE relname = l_sequence_name
        )
    THEN
        -- IF NOT then sql for create sequence

        -- get last doc number
        IF l_found_last_num
        THEN

            l_sql = 'select (max(SUBSTRING(''0'' || coalesce(tbl.number,''0''), ' || quote_literal('Y*[0-9]\d+') ||
                    ')::bigint) ::bigint) from docs.' || l_dok || ' tbl where rekvid = $1 ' ||
                    CASE WHEN l_dok = 'ARV' THEN ' and liik = 0' ELSE '' END;
            EXECUTE l_sql INTO l_number USING l_rekvid;

            IF length(l_number) > 6
            THEN
                l_number = '1';
            END IF;
        ELSE
            l_number = '1';
        END IF;

        l_sql = 'CREATE SEQUENCE ' || l_sequence_name || ' AS integer;' ||
                'GRANT ALL ON SEQUENCE ' || l_sequence_name || ' TO public;';

        IF l_number IS NOT NULL AND l_number::INTEGER > 0
        THEN
            -- will store last value
            l_sql = l_sql || 'select setval(' || quote_literal(l_sequence_name) || ',' || l_number || ');';

        END IF;

        -- execute sequnce
        EXECUTE l_sql;
    ELSE
        l_sql = 'GRANT ALL ON SEQUENCE ' || l_sequence_name || ' TO public;';

        IF l_number IS NOT NULL AND l_number::INTEGER > 0
        THEN
            -- will store last value
            l_sql = l_sql || 'select setval(' || quote_literal(l_sequence_name) || ',0);';

        END IF;

        -- execute sequnce
        EXECUTE l_sql;
    END IF;

    -- return name of sequence

    RETURN l_sequence_name;
END;
$_$;


ALTER FUNCTION docs.create_number_sequence(l_rekvid integer, l_dok text, l_found_last_num boolean) OWNER TO postgres;

--
-- TOC entry 310 (class 1255 OID 173166)
-- Name: create_return_mk(integer, jsonb); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.create_return_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION docs.create_return_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 296 (class 1255 OID 106598)
-- Name: year(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.year(date DEFAULT CURRENT_DATE) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN cast(extract(YEAR FROM $1) AS INT);
END;
$_$;


ALTER FUNCTION public.year(date) OWNER TO postgres;

--
-- TOC entry 291 (class 1255 OID 213592)
-- Name: kaive_aruanne(integer, date, date); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.kaive_aruanne(l_rekvid integer, kpv_start date DEFAULT make_date(public.year(CURRENT_DATE), 1, 1), kpv_end date DEFAULT CURRENT_DATE) RETURNS TABLE(id bigint, period date, nimi text, isikukood text, isik_id integer, alg_saldo numeric, arvestatud numeric, laekumised numeric, tagastused numeric, jaak numeric, rekvid integer)
    LANGUAGE sql
    AS $$
SELECT count(*) OVER (PARTITION BY report.isik_id) AS id,
       kpv_start::DATE                             AS period,
       a.nimetus::TEXT                             AS nimi,
       a.regkood::TEXT                             AS isikukood,
       a.id::INTEGER                               AS isik_id,
       alg_saldo::NUMERIC(14, 4),
       arvestatud::NUMERIC(14, 4),
       laekumised::NUMERIC(14, 4),
       tagastused::NUMERIC(14, 4),
       (alg_saldo + arvestatud - laekumised + tagastused)::NUMERIC(14, 4),
       report.rekv_id
FROM (
         WITH alg_saldo AS (
             SELECT isik_id, rekv_id, sum(summa) AS jaak
             FROM (
                      -- laekumised
                      SELECT -1 * (CASE WHEN mk.opt = 2 THEN 1 ELSE -1 END) * mk1.summa AS summa,
                             mk1.asutusid                                               AS isik_id,
                             d.rekvid                                                   AS rekv_id
                      FROM docs.doc d
                               INNER JOIN docs.Mk mk ON mk.parentid = d.id
                               INNER JOIN docs.Mk1 mk1 ON mk.id = mk1.parentid

                      WHERE d.status <> 3
                        AND d.rekvid = l_rekvid
                        AND mk.maksepaev < kpv_start
                      UNION ALL
                      SELECT -1 * sum(mk1.summa) AS summa,
                             mk.asutusid         AS isik_id,
                             d.rekvid            AS rekv_id
                      FROM docs.doc d
                               INNER JOIN docs.korder1 mk ON mk.parentid = d.id
                               INNER JOIN docs.korder2 mk1 ON mk.id = mk1.parentid
                      WHERE d.status <> 3
                        AND mk.tyyp = 1
                        AND mk1.summa > 0
                        AND d.rekvid = l_rekvid
                        AND mk.kpv < kpv_start
                      GROUP BY mk.asutusid, d.rekvid
                      UNION ALL
                      SELECT a.summa    AS summa,
                             a.asutusid AS isik_id,
                             d.rekvid   AS rekv_id
                      FROM docs.doc d
                               INNER JOIN docs.arv a ON a.parentid = d.id AND a.liik = 0 -- только счета исходящие
                      WHERE coalesce((a.properties ->> 'tyyp')::TEXT, '') <> 'ETTEMAKS'
                        AND d.rekvid = l_rekvid
                        AND a.liik = 0 -- только счета исходящие
                        AND a.kpv < kpv_start
-- mahakandmine
                      UNION ALL
                      SELECT -1 * a.summa AS summa,
                             arv.asutusid AS isik_id,
                             a.rekvid     AS rekv_id
                      FROM docs.arvtasu a
                               INNER JOIN docs.arv arv ON a.doc_arv_id = arv.parentid

                      WHERE a.pankkassa = 3 -- только проводки
                        AND a.rekvid = l_rekvid
                        AND a.kpv < kpv_start
                        AND a.status <> 3
                        AND (arv.properties ->> 'tyyp' IS NULL OR
                             arv.properties ->> 'tyyp' <> 'ETTEMAKS') -- уберем предоплаты

                  ) alg_saldo
             GROUP BY isik_id, rekv_id
         ),

              laekumised AS (
                  SELECT sum(mk1.summa) AS summa,
                         mk1.asutusid   AS isik_id,
                         d.rekvid       AS rekv_id
                  FROM docs.doc d
                           INNER JOIN docs.Mk mk ON mk.parentid = d.id
                           INNER JOIN docs.Mk1 mk1 ON mk.id = mk1.parentid
                  WHERE d.status <> 3
                    AND mk.opt = 2
                    AND mk1.summa > 0
                    AND d.rekvid = l_rekvid
                    AND mk.maksepaev >= kpv_start
                    AND mk.maksepaev <= kpv_end
                  GROUP BY mk1.asutusid, d.rekvid
                  UNION ALL
                  SELECT sum(mk1.summa) AS summa,
                         mk.asutusid    AS isik_id,
                         d.rekvid       AS rekv_id
                  FROM docs.doc d
                           INNER JOIN docs.korder1 mk ON mk.parentid = d.id
                           INNER JOIN docs.korder2 mk1 ON mk.id = mk1.parentid
                  WHERE d.status <> 3
                    AND mk.tyyp = 1
                    AND mk1.summa > 0
                    AND d.rekvid = l_rekvid
                    AND mk.kpv >= kpv_start
                    AND mk.kpv <= kpv_end
                  GROUP BY mk.asutusid, d.rekvid
              ),
              tagastused AS (
                  SELECT sum(CASE WHEN mk.opt = 2 THEN -1 ELSE 1 END * mk1.summa) AS summa,
                         mk1.asutusid                                             AS isik_id,
                         d.rekvid                                                 AS rekv_id
                  FROM docs.doc d
                           INNER JOIN docs.Mk mk ON mk.parentid = d.id
                           INNER JOIN docs.Mk1 mk1 ON mk.id = mk1.parentid
                  WHERE d.status <> 3
                    AND (mk.opt = 1 OR (mk.opt = 2 AND mk1.summa < 0))
                    AND d.rekvid = l_rekvid
                    AND mk.maksepaev >= kpv_start
                    AND mk.maksepaev <= kpv_end
                  GROUP BY mk1.asutusid, d.rekvid
              ),

              arvestatud AS (
                  SELECT a.asutusid                     AS isik_id,
                         sum(a1.summa) ::NUMERIC(14, 4) AS arvestatud,
                         D.rekvid::INTEGER              AS rekv_id
                  FROM docs.doc D
                           INNER JOIN docs.arv a ON a.parentid = D.id AND a.liik = 0 -- только счета исходящие
                           INNER JOIN (SELECT a1.parentid             AS arv_id,
                                              sum(a1.summa) AS summa
                                       FROM docs.arv1 a1
                                                INNER JOIN docs.arv a ON a.id = a1.parentid AND
                                                                         (a.properties ->> 'tyyp' IS NULL OR a.properties ->> 'tyyp' <> 'ETTEMAKS')
                                           AND a.liik = 0 -- только счета исходящие

                                                INNER JOIN docs.doc D ON D.id = a.parentid AND D.status <> 3
                                       GROUP BY a1.parentid) a1
                                      ON a1.arv_id = a.id
                  WHERE COALESCE((a.properties ->> 'tyyp')::TEXT, '') <> 'ETTEMAKS'
                    AND D.rekvid = l_rekvid
                    AND a.liik = 0 -- только счета исходящие
                    AND a.kpv >= kpv_start
                    AND a.kpv <= kpv_end
                  GROUP BY a.asutusid, D.rekvid
              )
         SELECT sum(alg_saldo)  AS alg_saldo,
                sum(arvestatud) AS arvestatud,
                sum(laekumised) AS laekumised,
                sum(tagastused) AS tagastused,
                qry.rekv_id,
                qry.isik_id
         FROM (
                  -- alg.saldo
                  SELECT a.jaak    AS alg_saldo,
                         0         AS arvestatud,
                         0         AS laekumised,
                         0         AS tagastused,
                         a.rekv_id AS rekv_id,
                         a.isik_id
                  FROM alg_saldo a
                  UNION ALL
                  -- laekumised
                  SELECT 0         AS alg_saldo,
                         0         AS arvestatud,
                         l.summa   AS laekumised,
                         0         AS tagastused,
                         l.rekv_id AS rekv_id,
                         l.isik_id
                  FROM laekumised l
                  UNION ALL
                  -- tagastused
                  SELECT 0                    AS alg_saldo,
                         0                    AS arvestatud,
                         0                    AS laekumised,
                         coalesce(t.summa, 0) AS tagastused,
                         t.rekv_id            AS rekv_id,
                         t.isik_id
                  FROM tagastused t
                  UNION ALL
                  -- arvestused
                  SELECT 0            AS alg_saldo,
                         k.arvestatud AS arvestatud,
                         0            AS laekumised,
                         0            AS tagastused,
                         k.rekv_id    AS rekv_id,
                         k.isik_id
                  FROM arvestatud k
              ) qry
         GROUP BY isik_id, rekv_id
     ) report
         INNER JOIN libs.asutus a ON report.isik_id = a.id

$$;


ALTER FUNCTION docs.kaive_aruanne(l_rekvid integer, kpv_start date, kpv_end date) OWNER TO postgres;

--
-- TOC entry 315 (class 1255 OID 123149)
-- Name: koosta_arve_lepingu_alusel(integer, integer, date); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.koosta_arve_lepingu_alusel(user_id integer, l_leping_id integer, l_kpv date DEFAULT CURRENT_DATE, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text, OUT viitenr text) RETURNS record
    LANGUAGE plpgsql
    AS $$

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
$$;


ALTER FUNCTION docs.koosta_arve_lepingu_alusel(user_id integer, l_leping_id integer, l_kpv date, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text, OUT viitenr text) OWNER TO postgres;

--
-- TOC entry 321 (class 1255 OID 172565)
-- Name: sp_delete_arvtasu(integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_delete_arvtasu(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
  v_doc    RECORD;
  l_doc_id INTEGER = 0;
BEGIN

  SELECT
    d.*,
    u.ametnik AS user_name
  INTO v_doc
  FROM docs.arvtasu d
    LEFT OUTER JOIN ou.userid u ON u.id = userid
  WHERE d.id = doc_id limit 1;

  IF v_doc IS NULL
  THEN
    error_code = 6;
    error_message = 'Dokument ei leitud, docId: ' || coalesce(doc_id, 0) :: TEXT;
    result = 0;
    RETURN;

  END IF;

  IF NOT exists(SELECT id
                FROM ou.userid u
                WHERE id = userid
                      AND (u.rekvid = v_doc.rekvid OR v_doc.rekvid IS NULL OR v_doc.rekvid = 0)
  )
  THEN

    error_code = 5;
    error_message = 'Kasutaja ei leitud, rekvId: ' || coalesce(v_doc.rekvid, 0) :: TEXT || ', userId:' ||
                    coalesce(userid, 0) :: TEXT;
    result = 0;
    RETURN;

  END IF;

  UPDATE docs.arvtasu
  SET status = 3
  WHERE id = doc_id
  RETURNING ID
    INTO l_doc_id;

-- уберем связи
  UPDATE docs.doc SET docs_ids = array_remove(docs_ids, v_doc.doc_tasu_id) WHERE id = v_doc.doc_arv_id;
  UPDATE docs.doc SET docs_ids = array_remove(docs_ids, v_doc.doc_arv_id) WHERE id = v_doc.doc_tasu_id;

  -- update arv jaak
  PERFORM docs.sp_update_arv_jaak(v_doc.doc_arv_id);

  -- сальдо платежа
  PERFORM docs.sp_update_mk_jaak(v_doc.doc_tasu_id);

  result = 1;

  RETURN;

  EXCEPTION WHEN OTHERS
  THEN
    RAISE NOTICE 'error % %', SQLERRM, SQLSTATE;
    RETURN;
END;$$;


ALTER FUNCTION docs.sp_delete_arvtasu(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 316 (class 1255 OID 180327)
-- Name: sp_delete_korder(integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_delete_korder(user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
  v_doc           RECORD;
  korder1_history JSONB;
  korder2_history JSONB;
  arvtasu_history JSONB;
  new_history     JSONB;
  DOC_STATUS      INTEGER = 3; -- документ удален
BEGIN

  SELECT
    d.*,
    k.arvid,
    u.ametnik AS user_name
  INTO v_doc
  FROM docs.doc d
    INNER JOIN docs.korder1 k on k.parentid = d.id
    LEFT OUTER JOIN ou.userid u ON u.id = user_id
  WHERE d.id = doc_id;

  -- проверка на пользователя и его соответствие учреждению

  IF v_doc IS NULL
  THEN
    error_code = 6;
    error_message = 'Dokument ei leitud, docId: ' || coalesce(doc_id, 0) :: TEXT;
    result = 0;
    RETURN;

  END IF;

  IF NOT exists(SELECT id
                FROM ou.userid u
                WHERE id = user_id
                      AND u.rekvid = v_doc.rekvid
  )
  THEN

    error_code = 5;
    error_message = 'Kasutaja ei leitud, rekvId: ' || coalesce(v_doc.rekvid, 0) :: TEXT || ', userId:' ||
                    coalesce(user_id, 0) :: TEXT;
    result = 0;
    RETURN;

  END IF;

  -- проверка на права. Предполагает наличие прописанных прав на удаление для данного пользователя в поле rigths



  -- Проверка на наличие связанных документов и их типов (если тип не проводка, то удалять нельзя кроме проводки)

  IF exists(
      SELECT d.id
      FROM docs.doc d
        INNER JOIN libs.library l ON l.id = d.doc_type_id
      WHERE d.id IN (SELECT unnest(v_doc.docs_ids))
            AND l.kood IN (
        SELECT kood
        FROM libs.library
        WHERE library = 'DOK'
              AND kood NOT IN ('JOURNAL','ARV')
              AND (properties IS NULL OR properties :: JSONB @> '{"type":"document"}')
      ))
  THEN

    RAISE NOTICE 'Есть связанные доку менты. удалять нельзя';
    error_code = 3; -- Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid
    error_message = 'Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid';
    result = 0;
    RETURN;
  END IF;

  -- Логгирование удаленного документа
  -- docs.arv

  korder1_history = row_to_json(row.*) FROM ( SELECT a.*
  FROM docs.korder1 a WHERE a.parentid = doc_id) ROW;

  -- docs.mk1

  korder2_history = jsonb_build_array(array(SELECT row_to_json(row.*)
                                            FROM (SELECT k1.*
                                                  FROM docs.mk1 k1
                                                    INNER JOIN docs.mk k ON k.id = k1.parentid
                                                  WHERE k.parentid = doc_id) row));
  -- docs.arvtasu

  arvtasu_history = jsonb_build_array(array(SELECT row_to_json(row.*)
                                            FROM (SELECT at.*
                                                  FROM docs.arvtasu at
                                                    INNER JOIN docs.korder1 k ON k.id = at.doc_tasu_id
                                                  WHERE k.parentid = doc_id) row));

  SELECT row_to_json(row)
  INTO new_history
  FROM (SELECT
          now()           AS deleted,
          v_doc.user_name AS user,
          korder1_history AS korder1,
          korder2_history AS korder2,
          arvtasu_history AS arvtasu) row;


  DELETE FROM docs.korder2
  WHERE parentid IN (SELECT id
                     FROM docs.arv
                     WHERE parentid = v_doc.id);
  DELETE FROM docs.korder1
  WHERE parentid = v_doc.id; --@todo констрейн на удаление

  -- удаляем оплату
  PERFORM docs.sp_delete_arvtasu(user_id, id)
  FROM docs.arvtasu a
  WHERE a.doc_tasu_id = doc_id;

  -- перерасчет сальдо связанного счета
  PERFORM docs.sp_update_arv_jaak(v_doc.arvid);

  -- удаление связей
  UPDATE docs.doc
  SET docs_ids = array_remove(docs_ids, doc_id)
  WHERE id IN (
    SELECT unnest(v_doc.docs_ids)
  )
        AND status < DOC_STATUS;

  -- Установка статуса ("Удален")  и сохранение истории
  UPDATE docs.doc
  SET lastupdate = now(),
    history      = coalesce(history, '[]') :: JSONB || new_history,
    rekvid       = v_doc.rekvid,
    status       = DOC_STATUS
  WHERE id = doc_id;

 
  result = 1;
  RETURN;
END;$$;


ALTER FUNCTION docs.sp_delete_korder(user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 314 (class 1255 OID 106619)
-- Name: sp_delete_leping(integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_delete_leping(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_doc           RECORD;
    v_dependid_docs RECORD;
    leping_id       INTEGER;
    ids             INTEGER[];
    leping1_history JSONB;
    leping2_history JSONB;
    new_history     JSONB;
    DOC_STATUS      INTEGER = 3; -- документ удален
BEGIN

    SELECT d.*,
           u.ametnik AS user_name
    INTO v_doc
    FROM docs.doc d
             LEFT OUTER JOIN ou.userid u ON u.id = userid
    WHERE d.id = doc_id;

    -- проверка на пользователя и его соответствие учреждению

    IF NOT exists(SELECT id
                  FROM ou.userid u
                  WHERE id = userid
                    AND u.rekvid = v_doc.rekvid
        )
    THEN

        error_code = 5;
        error_message = 'Kasutaja ei leitud';
        result = 0;
        RETURN;

    END IF;

    -- проверка на права. Предполагает наличие прописанных прав на удаление для данного пользователя в поле rigths


    -- Логгирование удаленного документа
    -- docs.leping1

    leping1_history = row_to_json(row.*)
                      FROM (SELECT a.*
                            FROM docs.leping1 a
                            WHERE a.parentid = doc_id) ROW;

    -- docs.leping2

    leping2_history = jsonb_build_array(array(SELECT row_to_json(row.*)
                                              FROM (SELECT l2.*
                                                    FROM docs.leping2 l2
                                                             INNER JOIN docs.leping1 l1 ON l1.id = l2.parentid
                                                    WHERE l1.parentid = doc_id) row));

    SELECT row_to_json(row)
    INTO new_history
    FROM (SELECT now()           AS deleted,
                 v_doc.user_name AS user,
                 leping1_history AS leping1,
                 leping2_history AS leping2) row;


    DELETE
    FROM docs.leping2
    WHERE parentid IN (SELECT id
                       FROM docs.leping1
                       WHERE parentid = v_doc.id);
    DELETE
    FROM docs.leping1
    WHERE parentid = v_doc.id;
    --@todo констрейн на удаление

    -- Установка статуса ("Удален")  и сохранение истории

    UPDATE docs.doc
    SET lastupdate = now(),
        history    = coalesce(history, '[]') :: JSONB || new_history,
        rekvid     = v_doc.rekvid,
        status     = DOC_STATUS
    WHERE id = doc_id;

    result = 1;
    RETURN;
END;
$$;


ALTER FUNCTION docs.sp_delete_leping(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 323 (class 1255 OID 172637)
-- Name: sp_delete_mk(integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_delete_mk(l_user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_doc           RECORD;
    mk_history      JSONB;
    mk1_history     JSONB;
    arvtasu_history JSONB;
    new_history     JSONB;
    DOC_STATUS      INTEGER = 3; -- документ удален

BEGIN

    SELECT d.*,
           (m.properties ->> 'ebatoenaolised_tagastamine_id')::INTEGER AS ebatoenaolised_tagastamine_id,
           u.ametnik                                                   AS user_name
    INTO v_doc
    FROM docs.doc d
             LEFT OUTER JOIN docs.mk m ON m.parentid = d.id
             LEFT OUTER JOIN ou.userid u ON u.id = l_user_id
    WHERE d.id = doc_id;

    -- проверка на пользователя и его соответствие учреждению

    IF v_doc IS NULL
    THEN
        error_code = 6;
        error_message = 'Dokument ei leitud, docId: ' || coalesce(doc_id, 0) :: TEXT;
        result = 0;
        RETURN;

    END IF;

    IF NOT exists(SELECT u.id
                  FROM ou.userid u
                  WHERE u.id = l_user_id
                    AND u.rekvid = v_doc.rekvid
        )
    THEN

        error_code = 5;
        error_message = 'Kasutaja ei leitud, rekvId: ' || coalesce(v_doc.rekvid, 0) :: TEXT || ', userId:' ||
                        coalesce(l_user_id, 0) :: TEXT;
        result = 0;
        RETURN;

    END IF;

    -- Проверка на наличие связанных документов и их типов (если тип не проводка, то удалять нельзя)

    IF exists(
            SELECT d.id
            FROM docs.doc d
                     INNER JOIN libs.library l ON l.id = d.doc_type_id
            WHERE d.id IN (SELECT unnest(v_doc.docs_ids))
              AND l.kood IN ('MK', 'SORDER', 'KORDER'))
    THEN

        RAISE NOTICE 'Есть связанные доку менты. удалять нельзя';
        error_code = 3; -- Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid
        error_message = 'Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid';
        result = 0;
        RETURN;
    END IF;

    -- Логгирование удаленного документа
    -- docs.arv

    mk_history = row_to_json(row.*)
                 FROM (SELECT a.*
                       FROM docs.mk a
                       WHERE a.parentid = doc_id) ROW;

    -- docs.mk1

    mk1_history = jsonb_build_array(array(SELECT row_to_json(row.*)
                                          FROM (SELECT k1.*
                                                FROM docs.mk1 k1
                                                         INNER JOIN docs.mk k ON k.id = k1.parentid
                                                WHERE k.parentid = doc_id) row));
    -- docs.arvtasu

    arvtasu_history = jsonb_build_array(array(SELECT row_to_json(row.*)
                                              FROM (SELECT at.*
                                                    FROM docs.arvtasu at
                                                             INNER JOIN docs.mk k ON k.id = at.doc_tasu_id
                                                    WHERE k.parentid = doc_id) row));


    SELECT row_to_json(row)
    INTO new_history
    FROM (SELECT now()           AS deleted,
                 v_doc.user_name AS user,
                 mk_history      AS mk,
                 mk1_history     AS mk1,
                 arvtasu_history AS arvtasu) row;

    -- Удаление данных из связанных таблиц (удаляем проводки)

    DELETE
    FROM docs.mk1
    WHERE parentid IN (SELECT a.id
                       FROM docs.arv a
                       WHERE a.parentid = v_doc.id);
    DELETE
    FROM docs.mk mk
    WHERE mk.parentid = v_doc.id;
    --@todo констрейн на удаление

    -- удаляем оплату

    DELETE
    FROM docs.arvtasu
    WHERE doc_tasu_id = v_doc.id;


/*    -- удаляем ссылку на данные из выписки
    UPDATE lapsed.pank_vv SET doc_id = NULL WHERE pank_vv.doc_id = v_doc.id;
*/
    -- удаляем возврат маловероятных , если есть
/*    IF (v_doc.ebatoenaolised_tagastamine_id IS NOT NULL)
    THEN
        PERFORM docs.sp_delete_journal(l_user_id, v_doc.ebatoenaolised_tagastamine_id);
    END IF;
*/
    -- удаление связей
    UPDATE docs.doc
    SET docs_ids = array_remove(docs_ids, doc_id)
    WHERE id IN (
        SELECT unnest(docs_ids)
        FROM docs.doc d
        WHERE d.id = doc_id
    )
      AND status < DOC_STATUS;


/*    IF (v_doc.docs_ids IS NOT NULL)
    THEN
        PERFORM docs.sp_delete_journal(l_user_id, parentid)
        FROM docs.journal
        WHERE parentid IN (SELECT unnest(v_doc.docs_ids));
    END IF;
*/
    -- Установка статуса ("Удален")  и сохранение истории

    UPDATE docs.doc
    SET lastupdate = now(),
        docs_ids   = NULL,
        history    = coalesce(history, '[]') :: JSONB || new_history,
        rekvid     = v_doc.rekvid,
        status     = DOC_STATUS
    WHERE id = doc_id;


    result = 1;
    RETURN;
END;
$$;


ALTER FUNCTION docs.sp_delete_mk(l_user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 295 (class 1255 OID 106597)
-- Name: sp_get_number(integer, text, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_get_number(l_rekvid integer, l_dok text, l_year integer, l_dokpropid integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_number          RECORD;
    lcPref            TEXT = '%';
    lcNumber          TEXT = '0';
    lcTableName       TEXT;
    lcAdditionalWhere TEXT = '';
    lcSqlString       TEXT;
    l_seq_name        TEXT;
BEGIN

    IF l_dokpropid IS NOT NULL
    THEN
        SELECT ltrim(rtrim(proc_)) INTO lcPref
        FROM libs.dokprop
        WHERE id = l_dokpropid;
    END IF;

    lcPref = coalesce(lcPref, '%');

    CASE
        WHEN l_dok = 'ARV'
            THEN
                lcTableName = 'docs.arv';
                lcAdditionalWhere = ' and liik = 0 ';

                l_seq_name = docs.create_number_sequence(l_rekvid, l_dok);
                SELECT nextval(l_seq_name) AS number INTO v_number;
        WHEN l_dok = 'TEATIS'
            THEN
                l_seq_name = docs.create_number_sequence(l_rekvid, l_dok, false);
                SELECT nextval(l_seq_name) AS number INTO v_number;
        WHEN l_dok = 'SARV'
            THEN
                lcTableName = 'docs.arv';
                lcAdditionalWhere = ' and liik = 1 and operid is not null and not empty(operid)';
        WHEN l_dok = 'SORDER'
            THEN
                lcTableName = 'docs.korder1';
                lcAdditionalWhere = ' and tyyp = 1 ';
        WHEN l_dok = 'VORDER'
            THEN
                lcTableName = 'docs.korder1';
                lcAdditionalWhere = ' and tyyp = 2 ';
        WHEN l_dok = 'MK'
            THEN
                lcTableName = 'docs.mk';
                lcAdditionalWhere = ' and OPT = 1 ';
        WHEN l_dok = 'SMK'
            THEN
                lcTableName = 'docs.mk';
                lcAdditionalWhere = ' and OPT = 1 ';
                l_seq_name = docs.create_number_sequence(l_rekvid, l_dok, FALSE);
                SELECT nextval(l_seq_name) AS number INTO v_number;
        WHEN l_dok = 'VMK'
            THEN
                lcTableName = 'docs.mk';
                lcAdditionalWhere = ' and OPT = 2 ';
        WHEN l_dok = 'LEPING'
            THEN
                lcTableName = 'docs.leping1';
        WHEN l_dok = 'TAOTLUS'
            THEN
                lcTableName = 'eelarve.taotlus';
        WHEN l_dok = 'LUBA'
            THEN
                lcTableName =
                        '(select left(l.number,2)::text as number, l.parentid, l.rekvid, l.algkpv as kpv from rekl.luba l)';
        END CASE;

    IF l_dok NOT IN ('ARV', 'SMK', 'TEATIS')
    THEN
        -- building sql query with regexp for only numbers
        lcSqlString = 'select (max(SUBSTRING(''0'' || coalesce(tbl.number,''0''), ' || quote_literal('Y*[0-9]\d+') ||
                      ')::bigint) ::bigint) as number from docs.doc d inner join '
            || lcTableName || ' tbl on d.id = tbl.parentid and d.status <> 3 '
            ||
                      ' where tbl.rekvId = $1::integer and year(tbl.kpv) = $2::integer and encode(tbl.number::bytea, ''escape'')::text  ilike $3::text';

        lcSqlString = lcSqlString || lcAdditionalWhere;
        EXECUTE lcSqlString
            INTO v_number
            USING l_rekvid, l_year, lcPref;
    END IF;

    -- will plus pref and encrement

    IF lcPref = '%'
    THEN
        lcPref = '';
    END IF;

    lcNumber = lcPref || (coalesce(v_number.number, 0) + 1) :: TEXT;

    RETURN lcNumber;
END;
$_$;


ALTER FUNCTION docs.sp_get_number(l_rekvid integer, l_dok text, l_year integer, l_dokpropid integer) OWNER TO postgres;

--
-- TOC entry 307 (class 1255 OID 172704)
-- Name: sp_loe_arv(integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_loe_arv(l_arv_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
    l_arv_jaak NUMERIC; -- остаток оплаты
    l_tasu     NUMERIC; -- сумма оплаты
    v_mk       RECORD;
    v_arve     RECORD;
BEGIN
    -- расчет сальдо счета
    l_arv_jaak = docs.sp_update_arv_jaak(l_arv_id);

    IF coalesce(l_arv_jaak, 0) > 0
    THEN

        -- load tasu data
        SELECT d.id,
               d.rekvid,
               arv.summa  AS summa,
               arv.jaak
               INTO v_arve
        FROM docs.doc D
                 INNER JOIN docs.arv arv ON arv.parentid = D.id
        WHERE d.id = l_arv_id;

        IF v_arve IS NULL
        THEN
            -- нет связи, вызодим
            result = 0;
            error_message = 'laps ei leidnud';
            RETURN;
        END IF;

        -- ищем не распределенные оплаты
        FOR v_mk IN
            SELECT mk.id,
                   mk.jaak,
                   mk.rekvid,
                   mk,
                   mk.asutusid as  maksja_id,
                   mk.nimetus AS maksja
            FROM cur_pank mk
            WHERE mk.rekvid = v_arve.rekvid
              AND mk.jaak > 0
            ORDER BY MK.kpv ASC
            LOOP
                -- списываем в оплату сальдо счета (только остаток счета)
                IF l_arv_jaak >= v_mk.jaak
                THEN
                    -- в оплату пошел остаток платежа
                    l_tasu = v_mk.jaak;
                ELSE
                    --в оплату пошел сальдо счета
                    l_tasu = l_arv_jaak;
                END IF;

                -- вызывает оплату
                -- l_tasu_id integer, l_arv_id integer,
                result = docs.sp_tasu_arv(v_mk.id, v_arve.id, l_user_id, l_tasu);

                IF result IS NOT NULL AND result > 0
                THEN
                    -- минусуем сумму оплаты
                    l_arv_jaak = l_arv_jaak - l_tasu;
                END IF;
                
                -- если оплата счета списана, но выходим из цикла
                IF l_arv_jaak = 0
                THEN
                    EXIT;
                END IF;
            END LOOP;

    END IF;
    
    return;
    
END;
$$;


ALTER FUNCTION docs.sp_loe_arv(l_arv_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 3847 (class 0 OID 0)
-- Dependencies: 307
-- Name: FUNCTION sp_loe_arv(l_arv_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: COMMENT; Schema: docs; Owner: postgres
--

COMMENT ON FUNCTION docs.sp_loe_arv(l_arv_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) IS 'производит поиск неоплаченных счетов и вызывает процедуру их оплаты';


--
-- TOC entry 324 (class 1255 OID 172692)
-- Name: sp_loe_tasu(integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_loe_tasu(l_tasu_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
    l_tasu_jaak NUMERIC; -- остаток оплаты
    l_tasu      NUMERIC; -- сумма оплаты
    v_arv       RECORD;
    v_tasu      RECORD;
BEGIN
    -- расчет сальдо платежа
    l_tasu_jaak = docs.sp_update_mk_jaak(l_tasu_id);

    IF coalesce(l_tasu_jaak, 0) > 0
    THEN

        -- load tasu data
        SELECT mk.id,
               d.rekvid,
               (regexp_replace(viitenr, '[^0-9]', ''))::TEXT                    AS viitenr,
               (SELECT sum(summa) FROM docs.mk1 mk1 WHERE mk1.parentid = mk.id) AS summa,
               jaak
               INTO v_tasu
        FROM docs.doc D
                 INNER JOIN docs.mk mk ON mk.parentid = D.id
        WHERE d.id = l_tasu_id;

        IF v_tasu IS NULL
        THEN
            -- нет связи, вызодим
            result = 0;
            error_message = 'laps ei leidnud';
            RETURN;
        END IF;

        --l_tasu_jaak = v_tasu.jaak;
        -- иницивлизируем = сумме остатка платежа

        -- ищем неоплаченные счета (по аналогии с выпиской)
        FOR v_arv IN
            SELECT a.id,
                   a.jaak,
                   a.rekvid,
                   a.asutusid,
                   a.asutus AS maksja
            FROM cur_arved a
                     INNER JOIN docs.arv arv ON a.id = arv.parentid
            WHERE a.rekvid = v_tasu.rekvid
              AND ltrim(rtrim((regexp_replace(a.viitenr, '[^0-9]', ''))))::TEXT =
                  ltrim(rtrim((regexp_replace(v_tasu.viitenr, '[^0-9]', ''))))::TEXT
              AND a.jaak > 0
--      AND a.jaak = v_tasu.summa
              AND (arv.properties ->> 'ettemaksu_period' IS NULL OR
                   arv.properties ->> 'tyyp' = 'ETTEMAKS') -- только обычные счета или предоплаты
            ORDER BY a.kpv, a.id
            LOOP
                -- списываем в оплату сальдо счета (только остаток счета)
                IF v_arv.jaak >= l_tasu_jaak
                THEN
                    -- в оплату пошел остаток платежа
                    l_tasu = l_tasu_jaak;
                ELSE
                    --в оплату пошел сальдо счета
                    l_tasu = v_arv.jaak;
                END IF;

                -- вызывает оплату
                result = docs.sp_tasu_arv(l_tasu_id, v_arv.id, l_user_id, l_tasu);

                IF result IS NOT NULL AND result > 0
                THEN
                    -- минусуем сумму оплаты
                    l_tasu_jaak = l_tasu_jaak - l_tasu;
                END IF;

                if l_tasu_jaak = 0 THEN
                    -- если оплата выбрана, то выходим
                    exit;
                END IF;
            END LOOP;

    END IF;

END;
$$;


ALTER FUNCTION docs.sp_loe_tasu(l_tasu_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 3849 (class 0 OID 0)
-- Dependencies: 324
-- Name: FUNCTION sp_loe_tasu(l_tasu_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: COMMENT; Schema: docs; Owner: postgres
--

COMMENT ON FUNCTION docs.sp_loe_tasu(l_tasu_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) IS 'производит поиск неоплаченных счетов и вызывает процедуру их оплаты';


--
-- TOC entry 318 (class 1255 OID 123135)
-- Name: sp_salvesta_arv(json, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_salvesta_arv(data json, user_id integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    arv_id                INTEGER;
    arv1_id               INTEGER;
    userName              TEXT;
    doc_id                INTEGER        = data ->> 'id';
    doc_data              JSON           = data ->> 'data';
    doc_type_kood         TEXT           = 'ARV'/*data->>'doc_type_id'*/;
    doc_type_id           INTEGER        = (SELECT id
                                            FROM libs.library
                                            WHERE kood = doc_type_kood
                                              AND library = 'DOK'
                                            LIMIT 1);

    doc_details           JSON           = coalesce(doc_data ->> 'gridData', doc_data ->> 'griddata');
    doc_number            TEXT           = doc_data ->> 'number';
    doc_summa             NUMERIC(14, 4) = coalesce((doc_data ->> 'summa') :: NUMERIC, 0);
    doc_liik              INTEGER        = doc_data ->> 'liik';
    doc_operid            INTEGER        = doc_data ->> 'operid';
    doc_asutusid          INTEGER        = doc_data ->> 'asutusid';
    doc_lisa              TEXT           = doc_data ->> 'lisa';
    doc_kpv               DATE           = doc_data ->> 'kpv';
    doc_tahtaeg_text      TEXT           = CASE
                                               WHEN (trim(doc_data ->> 'tahtaeg')::TEXT)::TEXT = '' THEN current_date::TEXT
                                               ELSE ((doc_data ->> 'tahtaeg')::TEXT) END;
    doc_tahtaeg           DATE           = doc_tahtaeg_text::DATE;
    doc_kbmta             NUMERIC(14, 4) = coalesce((doc_data ->> 'kbmta') :: NUMERIC, 0);
    doc_kbm               NUMERIC(14, 4) = coalesce((doc_data ->> 'kbm') :: NUMERIC, 0);
    doc_muud              TEXT           = doc_data ->> 'muud';
    doc_objektid          INTEGER        = doc_data ->> 'objektid'; -- считать или не считать (если не пусто) интресс
    doc_objekt            TEXT           = doc_data ->> 'objekt';
    tnDokLausId           INTEGER        = coalesce((doc_data ->> 'doklausid') :: INTEGER, 1);
    doc_lepingId          INTEGER        = doc_data ->> 'leping_id';
    doc_aa                TEXT           = doc_data ->> 'aa'; -- eri arve
    doc_viitenr           TEXT           = doc_data ->> 'viitenr'; -- viite number
    doc_type              TEXT           = doc_data ->> 'tyyp'; -- ETTEMAKS - если счет на предоплату

    dok_props             JSONB;

    json_object           JSON;
    json_record           RECORD;
    new_history           JSONB;
    new_rights            JSONB;
    ids                   INTEGER[];
    l_json_arve_id        JSONB;
    is_import             BOOLEAN        = data ->> 'import';

    arv1_rea_json         JSONB;
    l_jaak                NUMERIC;

    l_mk_id               INTEGER;
    l_km                  TEXT;
BEGIN

    -- если есть ссылка на ребенка, то присвоим viitenumber
    dok_props = (SELECT row_to_json(row)
                 FROM (SELECT doc_aa               AS aa,
                              doc_viitenr          AS viitenr
                      ) row);

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    IF doc_number IS NULL OR doc_number = ''
    THEN
        -- присвоим новый номер
        doc_number = docs.sp_get_number(user_rekvid, 'ARV', YEAR(doc_kpv), tnDokLausId);
    END IF;

    SELECT kasutaja INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = user_id;

    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;

-- установим срок оплаты, если не задан
    IF doc_tahtaeg IS NULL OR doc_tahtaeg < doc_kpv
    THEN
        doc_tahtaeg = doc_kpv + coalesce((SELECT tahtpaev FROM ou.config WHERE rekvid = user_rekvid LIMIT 1), 14);
    END IF;

    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;


        IF doc_lepingId IS NOT NULL
        THEN
            -- will add reference to leping
            ids = array_append(ids, doc_lepingId);
        END IF;


        INSERT INTO docs.doc (doc_type_id, history,rekvId)
        VALUES (doc_type_id, '[]' :: JSONB || new_history, user_rekvid);
        -- RETURNING id             INTO doc_id;

        SELECT currval('docs.doc_id_seq') INTO doc_id;

        ids = NULL;

        INSERT INTO docs.arv (parentid, rekvid, userid, liik, operid, number, kpv, asutusid, lisa, tahtaeg, kbmta, kbm,
                              summa, muud, objektid, objekt, doklausid, properties)
        VALUES (doc_id, user_rekvid, user_id, doc_liik, coalesce(doc_operid,0), doc_number, doc_kpv, doc_asutusid, doc_lisa,
                doc_tahtaeg,
                doc_kbmta, doc_kbm, doc_summa,
                doc_muud, doc_objektid, doc_objekt, tnDokLausId, dok_props) ;

        SELECT currval('docs.arv_id_seq') INTO arv_id;


    ELSE
        -- history
        SELECT row_to_json(row) INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;


        UPDATE docs.doc
        SET lastupdate = now(),
            history    = coalesce(history, '[]') :: JSONB || new_history,
            rekvid     = user_rekvid
        WHERE id = doc_id;

        IF doc_lepingId IS NOT NULL
        THEN
            -- will add reference to leping
            UPDATE docs.doc
            SET docs_ids = array_append(docs_ids, doc_lepingId)
            WHERE id = doc_id;
        END IF;

        UPDATE docs.arv
        SET liik       = doc_liik,
            operid     = doc_operid,
            number     = doc_number,
            kpv        = doc_kpv,
            asutusid   = doc_asutusid,
            lisa       = doc_lisa,
            tahtaeg    = doc_tahtaeg,
            kbmta      = coalesce(doc_kbmta, 0),
            kbm        = coalesce(doc_kbm, 0),
            summa      = coalesce(doc_summa, 0),
            muud       = doc_muud,
            objektid   = doc_objektid,
            objekt     = doc_objekt,
            doklausid  = tnDokLausId,
            properties = properties::jsonb || dok_props::jsonb
        WHERE parentid = doc_id RETURNING id
            INTO arv_id;

    END IF;

    -- вставка в таблицы документа
    FOR json_object IN
        SELECT *
        FROM json_array_elements(doc_details)
        LOOP
            SELECT * INTO json_record
            FROM json_to_record(
                         json_object) AS x (id TEXT, nomId INTEGER, kogus NUMERIC(14, 4), hind NUMERIC(14, 4),
                                            kbm NUMERIC(14, 4),
                                            kbmta NUMERIC(14, 4),
                                            summa NUMERIC(14, 4), kood TEXT, nimetus TEXT,
                                            konto TEXT, tunnus TEXT, proj TEXT, arve_id INTEGER, muud TEXT);



            IF json_record.id IS NULL OR json_record.id = '0' OR substring(json_record.id FROM 1 FOR 3) = 'NEW'
            THEN

                INSERT INTO docs.arv1 (parentid, nomid, kogus, hind, kbm, kbmta, summa,
                                       konto, tunnus, proj, muud)
                VALUES (arv_id, json_record.nomid,
                        coalesce(json_record.kogus, 1),
                        coalesce(json_record.hind, 0),
                        coalesce(json_record.kbm, 0),
                        coalesce(json_record.kbmta, coalesce(json_record.kogus, 1) * coalesce(json_record.hind, 0)),
                        coalesce(json_record.summa, (coalesce(json_record.kogus, 1) * coalesce(json_record.hind, 0)) +
                                                    coalesce(json_record.kbm, 0)),
                        coalesce(json_record.konto, ''),
                        coalesce(json_record.tunnus, ''),
                        coalesce(json_record.proj, ''),
                        coalesce(json_record.muud, '')) RETURNING id
                           INTO arv1_id;

                -- add new id into array of ids
                ids = array_append(ids, arv1_id);

            ELSE

                UPDATE docs.arv1
                SET parentid   = arv_id,
                    nomid      = json_record.nomid,
                    kogus      = coalesce(json_record.kogus, 0),
                    hind       = coalesce(json_record.hind, 0),
                    kbm        = coalesce(json_record.kbm, 0),
                    kbmta      = coalesce(json_record.kbmta, kogus * hind),
                    summa      = coalesce(json_record.summa, (kogus * hind) + kbm),
                    konto      = coalesce(json_record.konto, ''),
                    tunnus     = coalesce(json_record.tunnus, ''),
                    proj       = coalesce(json_record.proj, ''),
                    muud       = json_record.muud
                WHERE id = json_record.id :: INTEGER RETURNING id
                    INTO arv1_id;

                -- add new id into array of ids
                ids = array_append(ids, arv1_id);

            END IF;
        END LOOP;

    -- update arv summad
    SELECT sum(summa) AS summa,
           sum(kbm)   AS kbm
    INTO doc_summa, doc_kbm
    FROM docs.arv1
    WHERE parentid = arv_id;

    UPDATE docs.arv
    SET kbmta = coalesce(doc_summa, 0) - coalesce(doc_kbm, 0),
        kbm   = coalesce(doc_kbm, 0),
        summa = coalesce(doc_summa, 0)
    WHERE parentid = doc_id;

    -- расчет сальдо счета
    l_jaak = docs.sp_update_arv_jaak(doc_id);

    RETURN doc_id;
END;
$$;


ALTER FUNCTION docs.sp_salvesta_arv(data json, user_id integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 322 (class 1255 OID 172636)
-- Name: sp_salvesta_arvtasu(json, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_salvesta_arvtasu(data json, userid integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    lib_id          INTEGER;
    userName        TEXT;
    doc_id          INTEGER        = data ->> 'id';
    doc_data        JSON           = data ->> 'data';
    doc_rekvid      INTEGER        = doc_data ->> 'rekvid';
    doc_doc_arv_id  INTEGER        = doc_data ->> 'doc_arv_id';
    doc_doc_tasu_id INTEGER        = doc_data ->> 'doc_tasu_id';

    doc_kpv         DATE           = doc_data ->> 'kpv';
    doc_summa       NUMERIC(14, 2) = doc_data ->> 'summa';
    doc_pankkassa   INTEGER        = doc_data ->> 'pankkassa';
    doc_muud        TEXT           = doc_data ->> 'muud';
    v_tasu_dok      RECORD;
    is_import       BOOLEAN        = data ->> 'import';
    l_arv_tasud     NUMERIC        = 0;
    l_arv_summa     NUMERIC        = 0;

BEGIN

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    SELECT kasutaja INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;

    IF is_import IS NULL AND userName IS NULL
    THEN
        RETURN 0;
    END IF;

    -- 3 delete old payment

    IF doc_doc_arv_id IS NOT NULL
    THEN
        DELETE
        FROM docs.arvtasu
        WHERE doc_tasu_id = doc_doc_tasu_id
          AND doc_doc_arv_id NOT IN (SELECT doc_doc_arv_id -- не удаляем оплату текущего счета
                                     UNION
                                     SELECT unnest(d.docs_ids)
                                     FROM docs.doc d
                                     WHERE d.id = doc_doc_arv_id
        ) -- не удаляем связанные счета (предоплата)
          AND pankkassa = doc_pankkassa;
    END IF;

    -- проверяем на сумму оплат. Если счет уже оплачен , то доп. платежи не цепляем
    l_arv_tasud = coalesce((SELECT sum(summa) FROM docs.arvtasu WHERE doc_arv_id = doc_doc_arv_id AND status <> 3), 0);

    l_arv_summa = coalesce((SELECT summa FROM docs.arv WHERE parentid = doc_doc_arv_id), 0);

    IF l_arv_summa - l_arv_tasud <= 0 AND coalesce(doc_summa, 0) > 0
    THEN
        --  счет оплачен, новых платежей не надо

        -- update arv jaak
        PERFORM docs.sp_update_arv_jaak(doc_doc_arv_id);
        RETURN 0;
    END IF;

    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0
    THEN


        INSERT INTO docs.arvtasu (rekvid, doc_arv_id, doc_tasu_id, kpv, summa, muud, status, pankkassa)
        VALUES (doc_rekvid, doc_doc_arv_id, doc_doc_tasu_id, doc_kpv, doc_summa, doc_muud, 1,
                doc_pankkassa) RETURNING id
                   INTO lib_id;
    ELSE

        UPDATE docs.arvtasu
        SET doc_arv_id  = doc_doc_arv_id,
            doc_tasu_id = doc_doc_tasu_id,
            kpv         = doc_kpv,
            summa       = doc_summa,
            muud        = doc_muud,
            status      = CASE
                              WHEN status = 3
                                  THEN 1
                              ELSE status END
        WHERE id = doc_id RETURNING id
            INTO lib_id;
    END IF;

    -- установить связи
    -- добавим сязь счета и оплаты
    UPDATE docs.doc SET docs_ids = array_append(docs_ids, doc_doc_tasu_id) WHERE id = doc_doc_arv_id;

    -- добавим связь оплаты со счетом
    UPDATE docs.doc SET docs_ids = array_append(docs_ids, doc_doc_arv_id) WHERE id = doc_doc_tasu_id;


    -- update arv jaak
    PERFORM docs.sp_update_arv_jaak(doc_doc_arv_id);

    RETURN lib_id;

EXCEPTION
    WHEN OTHERS
        THEN
            RAISE NOTICE 'error % %', SQLERRM, SQLSTATE;
            RETURN 0;


END;
$$;


ALTER FUNCTION docs.sp_salvesta_arvtasu(data json, userid integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 319 (class 1255 OID 180336)
-- Name: sp_salvesta_korder(json, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_salvesta_korder(data json, userid integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    korder_id         INTEGER;
    korder1_id        INTEGER;
    userName          TEXT;
    doc_id            INTEGER = data ->> 'id';
    doc_data          JSON    = data ->> 'data';
    doc_tyyp          TEXT    = coalesce(doc_data ->> 'tyyp', '1'); -- 1 -> sorder, 2 -> vorder
    doc_type_kood     TEXT    = CASE
                                    WHEN doc_tyyp = '1'
                                        THEN 'SORDER'
                                    ELSE 'VORDER' END/*data->>'doc_type_id'*/;
    doc_type_id       INTEGER = (SELECT id
                                 FROM libs.library
                                 WHERE ltrim(rtrim(upper(kood))) = ltrim(rtrim(upper(doc_type_kood)))
                                   AND library = 'DOK'
                                 LIMIT 1);
    doc_details       JSON    = doc_data ->> 'gridData';
    doc_number        TEXT    = coalesce(doc_data ->> 'number', '1');
    doc_kpv           DATE    = doc_data ->> 'kpv';
    doc_asutusid      INTEGER = doc_data ->> 'asutusid';
    doc_kassa_id      INTEGER = doc_data ->> 'kassa_id';
    doc_doklausid     INTEGER = doc_data ->> 'doklausid';
    doc_dokument      TEXT    = doc_data ->> 'dokument';
    doc_nimi          TEXT    = doc_data ->> 'nimi';
    doc_aadress       TEXT    = doc_data ->> 'aadress';
    doc_alus          TEXT    = doc_data ->> 'alus';
    doc_arvid         INTEGER = doc_data ->> 'arvid';
    doc_muud          TEXT    = doc_data ->> 'muud';
    doc_summa         NUMERIC = doc_data ->> 'summa';
    json_object       JSON;
    json_record       RECORD;
    new_history       JSONB;
    ids               INTEGER[];
    docs              INTEGER[];
    arv_parent_id     INTEGER;
    previous_arv_id   INTEGER;
    DOC_STATUS_ACTIVE INTEGER = 1; -- документ открыт для редактирования
    is_import         BOOLEAN = data ->> 'import';
BEGIN

    SELECT kasutaja
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;
    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    IF doc_kassa_id IS NULL
    THEN
        SELECT id
        INTO doc_kassa_id
        FROM ou.aa
        WHERE parentId = user_rekvid
          AND kassa = 0
        ORDER BY default_ DESC
        LIMIT 1;
        IF NOT found
        THEN
            RAISE NOTICE 'Kassa not found %', doc_kassa_id;
            RETURN 0;
        ELSE
            --      RAISE NOTICE 'kassa: %', doc_kassa_id;
        END IF;
    END IF;

    IF doc_arvid IS NOT NULL
    THEN
        SELECT parentid
        INTO arv_parent_id
        FROM docs.arv
        WHERE id = doc_arvid;
        IF (SELECT count(*)
            FROM (
                     SELECT unnest(docs) AS element) qry
            WHERE element = arv_parent_id) = 0
        THEN
            docs = array_append(docs, arv_parent_id);
        END IF;
    END IF;

    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;


        INSERT INTO docs.doc (doc_type_id, history, rekvid, status)
        VALUES (doc_type_id, '[]' :: JSONB || new_history, user_rekvid, DOC_STATUS_ACTIVE);

        SELECT currval('docs.doc_id_seq') INTO doc_id;


        INSERT INTO docs.korder1 (parentid, rekvid, userid, kpv, asutusid, tyyp, kassaId, number, dokument, nimi,
                                  aadress, alus, muud, summa, arvid, doklausid)
        VALUES (doc_id, user_rekvid, userId, doc_kpv, doc_asutusid, doc_tyyp :: INTEGER, doc_kassa_id, doc_number,
                doc_dokument,
                doc_nimi,
                doc_aadress, doc_alus, doc_muud, doc_summa, doc_arvid, doc_doklausid) RETURNING id
                   INTO korder_id;

        --    raise notice 'korder_id %,  doc_id %', korder_id,  doc_id;

    ELSE
        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;

        -- устанавливаем связи с документами

        -- получим связи документа
        SELECT docs_ids
        INTO docs
        FROM docs.doc
        WHERE id = doc_id;

        -- will check if arvId exists

        IF doc_arvid IS NULL OR empty(doc_arvid)
        THEN
            SELECT arvid
            INTO previous_arv_id
            FROM docs.arv
            WHERE parentid = doc_id;
            IF previous_arv_id IS NOT NULL
            THEN
                -- remove from docs_ids
                docs = array_remove(docs, previous_arv_id);
                IF array_length(docs, 1) = 0
                THEN
                    docs = NULL;
                END IF;
            END IF;
        ELSE
            docs = array_append(docs, doc_arvid);
        END IF;


        UPDATE docs.doc
        SET docs_ids   = docs,
            lastupdate = now(),
            history    = coalesce(history, '[]') :: JSONB || new_history
        WHERE id = doc_id;

        UPDATE docs.korder1
        SET kpv       = doc_kpv,
            asutusid  = doc_asutusid,
            dokument  = doc_dokument,
            kassaid   = doc_kassa_id,
            doklausid = doc_doklausid,
            number    = doc_number,
            nimi      = doc_nimi,
            aadress   = doc_aadress,
            muud      = doc_muud,
            alus      = doc_alus,
            summa     = doc_summa,
            arvid     = doc_arvid
        WHERE parentid = doc_id RETURNING id
            INTO korder_id;

    END IF;
    -- вставка в таблицы документа


    FOR json_object IN
        SELECT *
        FROM json_array_elements(doc_details)
        LOOP
            SELECT *
            INTO json_record
            FROM json_to_record(
                         json_object) AS x (id TEXT, nomid INTEGER, summa NUMERIC(14, 4), nimetus TEXT, tunnus TEXT,
                                            proj TEXT,
                                            konto TEXT, muud TEXT);

            IF json_record.nimetus IS NULL
            THEN
                json_record.nimetus = (SELECT nimetus
                                       FROM libs.nomenklatuur
                                       WHERE id = json_record.nomid);
            END IF;

            IF json_record.id IS NULL OR json_record.id = '0' OR substring(json_record.id FROM 1 FOR 3) = 'NEW'
            THEN
                INSERT INTO docs.korder2 (parentid, nomid, nimetus, summa, tunnus, proj, konto, muud)
                VALUES (korder_id, json_record.nomid, json_record.nimetus, json_record.summa, json_record.tunnus,
                        json_record.proj,
                        json_record.konto, json_record.muud) RETURNING id
                           INTO korder1_id;

                -- add new id into array of ids
                ids = array_append(ids, korder1_id);

            ELSE

                UPDATE docs.korder2
                SET nomid   = json_record.nomid,
                    nimetus = json_record.nimetus,
                    summa   = json_record.summa,
                    tunnus  = json_record.tunnus,
                    proj    = json_record.proj,
                    muud    = json_record.muud
                WHERE id = json_record.id :: INTEGER;

                korder1_id = json_record.id :: INTEGER;

                -- add existing id into array of ids
                ids = array_append(ids, korder1_id);

            END IF;

            -- delete record which not in json

            DELETE
            FROM docs.korder2
            WHERE parentid = korder_id
              AND id NOT IN (SELECT unnest(ids));


        END LOOP;

    IF doc_arvid IS NOT NULL
    THEN
        -- произведем оплату счета
        PERFORM docs.sp_tasu_arv(doc_id, doc_arvid, userid);

    END IF;

    RETURN doc_id;

END;
$$;


ALTER FUNCTION docs.sp_salvesta_korder(data json, userid integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 306 (class 1255 OID 114722)
-- Name: sp_salvesta_leping(json, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_salvesta_leping(data json, userid integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    leping_id     INTEGER;
    leping2_id    INTEGER;
    userName      TEXT;
    doc_id        INTEGER = data ->> 'id';
    doc_type_kood TEXT    = 'LEPING'/*data->>'doc_type_id'*/;
    doc_type_id   INTEGER = (SELECT id
                             FROM libs.library
                             WHERE kood = doc_type_kood
                               AND library = 'DOK'
                             LIMIT 1);
    doc_data      JSON    = data ->> 'data';
    doc_details   JSON    = coalesce(doc_data ->> 'gridData', doc_data ->> 'griddata');
    doc_number    TEXT    = doc_data ->> 'number';
    doc_asutusid  INTEGER = doc_data ->> 'asutusid';
    doc_selgitus  TEXT    = doc_data ->> 'selgitus';
    doc_kpv       DATE    = doc_data ->> 'kpv';
    doc_tahtaeg   DATE    = doc_data ->> 'tahtaeg';
    doc_muud      TEXT    = doc_data ->> 'muud';
    doc_objektid  INTEGER = doc_data ->> 'objektid';
    json_object   JSON;
    json_record   RECORD;
    new_history   JSONB;
    new_rights    JSONB;
    ids           INTEGER[];
    is_import     BOOLEAN = data ->> 'import';
BEGIN

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    SELECT kasutaja
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;

    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;

    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;

        SELECT row_to_json(row)
        INTO new_rights
        FROM (SELECT ARRAY [userId] AS "select",
                     ARRAY [userId] AS "update",
                     ARRAY [userId] AS "delete") row;


        INSERT INTO docs.doc (doc_type_id, history, rekvId, status)
        VALUES (doc_type_id, '[]' :: JSONB || new_history, user_rekvid, 1) RETURNING id
            INTO doc_id;

        INSERT INTO docs.leping1 (parentid, rekvid, number, kpv, asutusid, selgitus, tahtaeg, muud, objektid)
        VALUES (doc_id, user_rekvid, doc_number, doc_kpv, doc_asutusid, doc_selgitus, doc_tahtaeg,
                doc_muud, doc_objektid) RETURNING id
                   INTO leping_id;

    ELSE
        -- history
        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;

        UPDATE docs.doc
        SET lastupdate = now(),
            history    = coalesce(history, '[]') :: JSONB || new_history,
            rekvid     = user_rekvid
        WHERE id = doc_id;

        UPDATE docs.leping1
        SET number   = doc_number,
            kpv      = doc_kpv,
            asutusid = doc_asutusid,
            selgitus = doc_selgitus,
            tahtaeg  = doc_tahtaeg,
            muud     = doc_muud,
            objektid = doc_objektid
        WHERE parentid = doc_id RETURNING id
            INTO leping_id;

    END IF;
    -- вставка в таблицы документа


    FOR json_object IN
        SELECT *
        FROM json_array_elements(doc_details)
        LOOP
            SELECT *
            INTO json_record
            FROM json_to_record(
                         json_object) AS x(id TEXT, nomId INTEGER, kogus NUMERIC(14, 4), hind NUMERIC(14, 4),
                                           summa NUMERIC(14, 4),
                                           muud TEXT, formula TEXT, kbm INTEGER,
                                           soodus INTEGER);

            IF json_record.id IS NULL OR json_record.id = '0' OR substring(json_record.id FROM 1 FOR 3) = 'NEW'
            THEN
                INSERT INTO docs.leping2 (parentid, nomid, kogus, hind, kbm, summa, muud, formula)
                VALUES (leping_id, json_record.nomid,
                        coalesce(json_record.kogus, 0),
                        coalesce(json_record.hind, 0),
                        coalesce(json_record.kbm, 0),
                        coalesce(json_record.summa, 0),
                        json_record.muud,
                        json_record.formula) RETURNING id
                           INTO leping2_id;

                -- add new id into array of ids
                ids = array_append(ids, leping2_id);

            ELSE
                UPDATE docs.leping2
                SET parentid = leping_id,
                    nomid    = json_record.nomid,
                    kogus    = coalesce(json_record.kogus, 0),
                    hind     = coalesce(json_record.hind, 0),
                    kbm      = coalesce(json_record.kbm, 0),
                    summa    = coalesce(json_record.summa, kogus * hind),
                    muud     = json_record.muud,
                    formula  = json_record.formula
                WHERE id = json_record.id :: INTEGER RETURNING id
                    INTO leping2_id;

                -- add new id into array of ids
                ids = array_append(ids, leping2_id);

            END IF;

        END LOOP;

    -- delete record which not in json

    DELETE
    FROM docs.leping2
    WHERE parentid = leping_id
      AND id NOT IN (SELECT unnest(ids));

    RETURN doc_id;
END;
$$;


ALTER FUNCTION docs.sp_salvesta_leping(data json, userid integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 305 (class 1255 OID 172706)
-- Name: sp_salvesta_mk(json, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_salvesta_mk(data json, user_id integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    mk_id             INTEGER;
    mk1_id            INTEGER;
    userName          TEXT;
    doc_id            INTEGER = data ->> 'id';
    doc_data          JSON    = data ->> 'data';
    doc_details       JSON    = doc_data ->> 'gridData';
    doc_opt           TEXT    = coalesce((doc_data ->> 'opt'), '1'); -- 2 -> smk, 1 -> vmk
    doc_type_kood     TEXT    = coalesce((doc_data ->> 'doc_type_id'), CASE
                                                                           WHEN doc_opt = '2'
                                                                               THEN 'SMK'
                                                                           ELSE 'VMK' END);
    doc_typeId        INTEGER = (SELECT id
                                 FROM libs.library
                                 WHERE ltrim(rtrim(kood)) = ltrim(rtrim(upper(doc_type_kood)))
                                   AND library = 'DOK'
                                 LIMIT 1);
    doc_number        TEXT    = doc_data ->> 'number';
    doc_kpv           DATE    = coalesce((doc_data ->> 'kpv')::DATE, current_date);
    doc_aa_id         INTEGER = coalesce((doc_data ->> 'aa_id')::INTEGER, (doc_data ->> 'aaid')::INTEGER);
    doc_arvid         INTEGER = doc_data ->> 'arvid';
    doc_muud          TEXT    = doc_data ->> 'muud';
    doc_doklausid     INTEGER = doc_data ->> 'doklausid';
    doc_maksepaev     DATE    = coalesce((doc_data ->> 'maksepaev')::DATE, current_date);
    doc_selg          TEXT    = doc_data ->> 'selg';
    doc_viitenr       TEXT    = doc_data ->> 'viitenr';
    doc_dok_id        INTEGER = doc_data ->> 'dokid'; -- kui mk salvestatud avansiaruanne alusel

    json_object       JSON;
    json_record       RECORD;
    new_history       JSONB;
    ids               INTEGER[];
    docs              INTEGER[];
    is_import         BOOLEAN = data ->> 'import';
    l_jaak            NUMERIC = 0; -- tasu jääk

    l_vana_tasu_summa NUMERIC = 0; -- vana tasu summa
    l_uus_tasu_summa  NUMERIC = 0; -- uus tasu summa
    kas_muudatus      BOOLEAN = FALSE; -- если апдейт, то тру
    v_arvtasu         RECORD;
BEGIN

    SELECT kasutaja
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = user_id;
    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    IF doc_number IS NULL OR doc_number = ''
    THEN
        -- присвоим новый номер
        doc_number = docs.sp_get_number(user_rekvid, 'SMK', YEAR(doc_kpv), doc_doklausid);
    END IF;

-- проверим расч. счет
    IF doc_aa_id IS NULL OR NOT exists(SELECT id
                                       FROM ou.aa
                                       WHERE parentId = user_rekvid
                                         AND kassa = 1
                                         AND id = doc_aa_id
                                       ORDER BY default_ DESC)
    THEN
        SELECT id
        INTO doc_aa_id
        FROM ou.aa
        WHERE parentId = user_rekvid
          AND kassa = 1
        ORDER BY default_ DESC
        LIMIT 1;
        IF NOT found
        THEN
            RAISE NOTICE 'pank not found %', doc_aa_id;
            RETURN 0;
        END IF;
    END IF;

    -- вставка или апдейт docs.doc

    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;


        INSERT INTO docs.doc (doc_type_id, history, rekvid, status)
        VALUES (doc_typeId, '[]' :: JSONB || new_history, user_rekvid, 1);
        --RETURNING id             INTO doc_id;
        SELECT currval('docs.doc_id_seq') INTO doc_id;


        INSERT INTO docs.mk (parentid, rekvid, kpv, opt, aaId, number, muud, arvid, doklausid, maksepaev, selg, viitenr,
                             dokid)
        VALUES (doc_id, user_rekvid, doc_kpv, doc_opt :: INTEGER, doc_aa_id, doc_number, doc_muud,
                coalesce(doc_arvid, 0),
                coalesce(doc_doklausid, 0), coalesce(doc_maksepaev, doc_kpv), coalesce(doc_selg, ''),
                coalesce(doc_viitenr, ''), coalesce(doc_dok_id, 0)) RETURNING id
                   INTO mk_id;

    ELSE
        kas_muudatus = TRUE;
        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;

        -- устанавливаем связи с документами

        -- получим связи документа
        SELECT docs_ids
        INTO docs
        FROM docs.doc
        WHERE id = doc_id;

        IF doc_arvid IS NOT NULL
        THEN
            docs = array_append(docs, doc_arvid);
        END IF;

        UPDATE docs.doc
        SET doc_type_id = doc_typeId,
            docs_ids    = docs,
            lastupdate  = now(),
            history     = coalesce(history, '[]') :: JSONB || new_history
        WHERE id = doc_id;

        UPDATE docs.mk
        SET kpv       = doc_kpv,
            aaid      = doc_aa_id,
            number    = doc_number,
            muud      = doc_muud,
            arvid     = coalesce(doc_arvid, 0),
            doklausid = coalesce(doc_doklausid, 0),
            maksepaev = coalesce(doc_maksepaev, doc_kpv),
            selg      = coalesce(doc_selg, ''),
            viitenr   = coalesce(doc_viitenr, ''),
            dokid     = coalesce(doc_dok_id, 0)
        WHERE parentid = doc_id RETURNING id
            INTO mk_id;

        -- если есть оплата счетов и меняется дата, правим
        UPDATE docs.arvtasu SET kpv = doc_kpv WHERE doc_tasu_id = doc_id;


        -- кешируем старую сумму оплаты
        SELECT sum(summa) INTO l_vana_tasu_summa FROM docs.mk1 WHERE parentid = mk_id;


    END IF;
    -- вставка в таблицы документа

    FOR json_object IN
        SELECT *
        FROM json_array_elements(doc_details)
        LOOP
            SELECT *
            INTO json_record
            FROM json_to_record(
                         json_object) AS x(id TEXT, asutusid INTEGER, nomid INTEGER, summa NUMERIC(14, 4), aa TEXT,
                                           pank TEXT,
                                           tunnus TEXT, proj TEXT, konto TEXT );

            IF json_record.id IS NULL OR json_record.id = '0' OR substring(json_record.id FROM 1 FOR 3) = 'NEW' OR
               NOT exists(SELECT id
                          FROM docs.mk1
                          WHERE id = json_record.id :: INTEGER)
            THEN

                INSERT INTO docs.mk1 (parentid, asutusid, nomid, summa, aa, pank, tunnus, proj, konto)
                VALUES (mk_id, json_record.asutusid, json_record.nomid, json_record.summa, json_record.aa,
                        json_record.pank,
                        json_record.tunnus, json_record.proj, json_record.konto) RETURNING id  INTO mk1_id;

                -- add new id into array of ids
                ids = array_append(ids, mk1_id);

            ELSE

                UPDATE docs.mk1
                SET nomid    = json_record.nomid,
                    asutusid = json_record.asutusid,
                    summa    = json_record.summa,
                    aa       = json_record.aa,
                    pank     = json_record.pank,
                    tunnus   = json_record.tunnus,
                    proj     = json_record.proj
                WHERE id = json_record.id :: INTEGER;

                mk1_id = json_record.id :: INTEGER;

                -- add existing id into array of ids
                ids = array_append(ids, mk1_id);

            END IF;

            -- delete record which not in json

            DELETE
            FROM docs.mk1
            WHERE parentid = mk_id
              AND id NOT IN (SELECT unnest(ids));

            l_uus_tasu_summa = l_uus_tasu_summa + json_record.summa;

        END LOOP;

    -- правим сумму оплаты
    IF (kas_muudatus)
    THEN

        IF l_uus_tasu_summa <> l_vana_tasu_summa
        THEN
            -- кешируем старую сумму оплаты
            SELECT *
            INTO v_arvtasu
            FROM docs.arvtasu
            WHERE doc_tasu_id = doc_id
              AND status <> 3
            ORDER BY summa DESC
            LIMIT 1;
            -- если сумма оплаты уменьшилась
            IF l_uus_tasu_summa < l_vana_tasu_summa AND v_arvtasu.summa > l_uus_tasu_summa
            THEN
                -- просто меняем сумму оплаты
                UPDATE docs.arvtasu SET summa = l_uus_tasu_summa WHERE id = v_arvtasu.id;
            ELSE
                -- удаляем оплату и распределяем счета по новой
                PERFORM docs.sp_delete_arvtasu(
                                user_id,
                                v_arvtasu.id);
            END IF;
        END IF;

    END IF;

    -- сальдо платежа
    l_jaak = docs.sp_update_mk_jaak(doc_id);


    IF doc_arvid IS NOT NULL AND doc_arvid > 0 AND l_jaak > 0
    THEN
        -- произведем оплату счета
        PERFORM docs.sp_tasu_arv(doc_id, doc_arvid, user_id);

    END IF;

    IF l_jaak > 0 AND doc_opt::INTEGER = 2 -- smk
    THEN
        -- произведем поиск и оплату счета
        PERFORM docs.sp_loe_tasu(doc_id, user_id);
    END IF;

    RETURN doc_id;

END;
$$;


ALTER FUNCTION docs.sp_salvesta_mk(data json, user_id integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 320 (class 1255 OID 115084)
-- Name: sp_salvesta_moodu(json, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_salvesta_moodu(data json, userid integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    moodu_id      INTEGER;
    moodu2_id     INTEGER;
    userName      TEXT;
    doc_id        INTEGER = data ->> 'id';
    doc_type_kood TEXT    = 'ANDMED'/*data->>'doc_type_id'*/;
    doc_type_id   INTEGER = (SELECT id
                             FROM libs.library
                             WHERE kood = doc_type_kood
                               AND library = 'DOK'
                             LIMIT 1);
    doc_data      JSON    = data ->> 'data';
    doc_details   JSON    = coalesce(doc_data ->> 'gridData', doc_data ->> 'griddata');
    doc_kpv       DATE    = doc_data ->> 'kpv';
    doc_muud      TEXT    = doc_data ->> 'muud';
    doc_lepingid  INTEGER = doc_data ->> 'lepingid';
    json_object   JSON;
    json_record   RECORD;
    new_history   JSONB;
    new_rights    JSONB;
    ids           INTEGER[];
    is_import     BOOLEAN = data ->> 'import';
BEGIN

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    SELECT kasutaja
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;

    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;

    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;

        SELECT row_to_json(row)
        INTO new_rights
        FROM (SELECT ARRAY [userId] AS "select",
                     ARRAY [userId] AS "update",
                     ARRAY [userId] AS "delete") row;


        INSERT INTO docs.doc (doc_type_id, history, rekvId, status)
        VALUES (doc_type_id, '[]' :: JSONB || new_history, user_rekvid, 1) RETURNING id
            INTO doc_id;

        INSERT INTO docs.moodu1 (parentid, kpv, lepingid, muud)
        VALUES (doc_id, doc_kpv, doc_lepingid, doc_muud) RETURNING id
            INTO moodu_id;

    ELSE
        -- history
        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;

        UPDATE docs.doc
        SET lastupdate = now(),
            history    = coalesce(history, '[]') :: JSONB || new_history,
            rekvid     = user_rekvid
        WHERE id = doc_id;

        UPDATE docs.moodu1
        SET kpv      = doc_kpv,
            lepingid = doc_lepingid,
            muud     = doc_muud
        WHERE parentid = doc_id RETURNING id
            INTO moodu_id;

    END IF;
    -- вставка в таблицы документа


    FOR json_object IN
        SELECT *
        FROM json_array_elements(doc_details)
        LOOP
            SELECT *
            INTO json_record
            FROM json_to_record(
                         json_object) AS x(id TEXT, nomId INTEGER, kogus NUMERIC(14, 4), hind NUMERIC(14, 4),
                                           summa NUMERIC(14, 4),
                                           muud TEXT, formula TEXT, kbm INTEGER,
                                           soodus INTEGER);

            IF json_record.id IS NULL OR json_record.id = '0' OR substring(json_record.id FROM 1 FOR 3) = 'NEW'
            THEN
                INSERT INTO docs.moodu2 (parentid, nomid, kogus, muud)
                VALUES (moodu_id, json_record.nomid,
                        coalesce(json_record.kogus, 0),
                        json_record.muud) RETURNING id
                           INTO moodu2_id;

                -- add new id into array of ids
                ids = array_append(ids, moodu2_id);

            ELSE
                UPDATE docs.moodu2
                SET parentid = moodu_id,
                    nomid    = json_record.nomid,
                    kogus    = coalesce(json_record.kogus, 0),
                    muud     = json_record.muud
                WHERE id = json_record.id :: INTEGER RETURNING id
                    INTO moodu2_id;

                -- add new id into array of ids
                ids = array_append(ids, moodu2_id);

            END IF;

        END LOOP;

    -- delete record which not in json

    DELETE
    FROM docs.moodu2
    WHERE parentid = moodu_id
      AND id NOT IN (SELECT unnest(ids));

    RETURN doc_id;
END;
$$;


ALTER FUNCTION docs.sp_salvesta_moodu(data json, userid integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 328 (class 1255 OID 196776)
-- Name: sp_salvesta_rekl(json, integer, integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_salvesta_rekl(data json, userid integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    rekl_id      INTEGER;
    userName      TEXT;
    doc_id        INTEGER = data ->> 'id';
    doc_type_kood TEXT    = 'REKL'/*data->>'doc_type_id'*/;
    doc_type_id   INTEGER = (SELECT id
                             FROM libs.library
                             WHERE kood = doc_type_kood
                               AND library = 'DOK'
                             LIMIT 1);
    doc_data      JSON    = data ->> 'data';
    doc_alg_kpv       DATE    = doc_data ->> 'alg_kpv';
    doc_lopp_kpv       DATE    = doc_data ->> 'lopp_kpv';
    doc_nimetus      TEXT    = doc_data ->> 'nimetus';
    doc_link      TEXT    = doc_data ->> 'link';
    doc_muud      TEXT    = doc_data ->> 'muud';
    doc_asutusid  INTEGER = doc_data ->> 'asutusid';
    json_object   JSON;
    json_record   RECORD;
    new_history   JSONB;
    is_import     BOOLEAN = data ->> 'import';
BEGIN

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    SELECT kasutaja
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;

    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;

    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;


        INSERT INTO docs.doc (doc_type_id, history, rekvId, status)
        VALUES (doc_type_id, '[]' :: JSONB || new_history, user_rekvid, 1) RETURNING id
            INTO doc_id;

        INSERT INTO docs.rekl (rekvid, parentid, alg_kpv, lopp_kpv, asutusid, nimetus, link, muud)
        VALUES (user_rekvid, doc_id, doc_alg_kpv, doc_lopp_kpv, doc_asutusid, doc_nimetus, doc_link, doc_muud) RETURNING id
            INTO rekl_id;

    ELSE
        -- history
        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;

        UPDATE docs.doc
        SET lastupdate = now(),
            history    = coalesce(history, '[]') :: JSONB || new_history,
            rekvid     = user_rekvid
        WHERE id = doc_id;

        UPDATE docs.rekl
        SET alg_kpv      = doc_alg_kpv,
            lopp_kpv = doc_lopp_kpv,
            asutusid = doc_asutusid,
            nimetus = doc_nimetus,
            link = doc_link,
            muud     = doc_muud
        WHERE parentid = doc_id RETURNING id
            INTO rekl_id;

    END IF;

    RETURN doc_id;
END;
$$;


ALTER FUNCTION docs.sp_salvesta_rekl(data json, userid integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 309 (class 1255 OID 172739)
-- Name: sp_tasu_arv(integer, integer, integer, numeric); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_tasu_arv(l_tasu_id integer, l_arv_id integer, l_user_id integer, tasu_summa numeric DEFAULT 0) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    l_doc_id         INTEGER;
    v_tasu           RECORD;
    v_params         RECORD;
    json_object      JSONB;
    l_tasu_type      INTEGER = 3; -- muud (lausend)
    l_summa          NUMERIC = 0;
    l_doc_tasu_id    INTEGER;
    TYPE_DOK_MK      INTEGER = 1;
    TYPE_DOK_KORDER  INTEGER = 2;
    TYPE_DOK_JOURNAL INTEGER = 3;
    v_arv            RECORD;
    v_tulu_arved     RECORD;
    l_tasu_summa     NUMERIC = 0;
    is_refund        BOOLEAN = FALSE;
BEGIN
    IF exists(SELECT 1 FROM docs.arv WHERE journalid = l_tasu_id)
    THEN
        -- это не оплата, это проводка счета
        RETURN 0;
    END IF;


    SELECT d.id,
           d.docs_ids,
           a.properties ->> 'tyyp'                                AS tyyp,
           CASE WHEN a.liik = 1 THEN 'KULU' ELSE 'TULU' END::TEXT AS arve_tyyp    INTO v_arv
    FROM docs.doc d
             INNER JOIN docs.arv a ON a.parentid = d.id
    WHERE d.id = l_arv_id;

    SELECT d.*,
           CASE
               WHEN m.maksepaev IS NOT NULL THEN m.maksepaev
               WHEN k.kpv IS NOT NULL THEN k.kpv
               ELSE d.created::DATE
               END AS maksepaev,
           l.kood  AS doc_type
    INTO v_tasu
    FROM docs.doc d
             INNER JOIN libs.library l ON l.id = d.doc_type_id
             LEFT OUTER JOIN docs.mk m ON m.parentid = d.id
             LEFT OUTER JOIN docs.korder1 k
                             ON k.parentid = D.id
    WHERE d.id = l_tasu_id;

    IF l_tasu_id IS NULL
    THEN
        -- Документ не найден
        RAISE NOTICE 'Документ не найден';
        RETURN 0;
    END IF;

    l_tasu_type = (CASE
                       WHEN v_tasu.doc_type ILIKE '%MK%'
                           THEN TYPE_DOK_MK
                       WHEN v_tasu.doc_type ILIKE '%ORDER%'
                           THEN TYPE_DOK_KORDER
                       ELSE TYPE_DOK_JOURNAL END);

    -- рассчитываем сумму оплаты, если платеж не задан

    l_summa = CASE
                  WHEN empty(tasu_summa) THEN (
                      SELECT sum(summa) AS summa
                      FROM (
                               SELECT summa * (CASE
                                                   WHEN v_arv.arve_tyyp = 'TULU' AND m.opt = 2 THEN 1
                                                   WHEN v_arv.arve_tyyp = 'TULU' AND m.opt = 1 THEN -1
                                                   WHEN v_arv.arve_tyyp = 'KULU' AND m.opt = 1 THEN 1
                                                   WHEN v_arv.arve_tyyp = 'KULU' AND m.opt = 2
                                                       THEN -1 END)::INTEGER AS summa
                               FROM docs.mk m
                                        INNER JOIN docs.mk1 m1 ON m.id = m1.parentid
                               WHERE m.parentid = l_tasu_id
                               UNION ALL
                               SELECT summa
                               FROM docs.korder1 k
                               WHERE k.parentid = l_tasu_id
                           ) tasud
                  )
                  ELSE tasu_summa END;

    l_doc_tasu_id = (
        SELECT a.id
        FROM docs.arvtasu a
        WHERE doc_arv_id = l_arv_id
          AND doc_tasu_id = l_tasu_id
          AND a.status <> 3
        ORDER BY a.id DESC
        LIMIT 1
    );

    SELECT coalesce(l_doc_tasu_id, 0)                         AS id,
           v_tasu.rekvid                                      AS rekvid,
           l_arv_id                                           AS doc_arv_id,
           v_tasu.maksepaev :: DATE                           AS kpv,
           l_tasu_type                                        AS pankkassa,
           -- 1 - mk, 2- kassa, 3 - lausend
           l_tasu_id                                          AS doc_tasu_id,
           l_summa * (CASE WHEN is_refund THEN -1 ELSE 1 END) AS summa
    INTO v_params;

    SELECT row_to_json(row)
    INTO json_object
    FROM (SELECT coalesce(l_doc_tasu_id, 0) AS id,
                 v_params                   AS data) row;

    SELECT docs.sp_salvesta_arvtasu(json_object :: JSON, l_user_id, v_tasu.rekvid) INTO l_doc_id;

    -- если счет имеет тип - предоплата

    IF v_arv.tyyp = 'ETTEMAKS'
    THEN
        -- выбираем связанные счета
        FOR v_tulu_arved IN
            SELECT d.id, a.jaak
            FROM docs.doc d
                     INNER JOIN docs.arv a ON d.id = a.parentid
            WHERE d.id IN (
                SELECT unnest(v_arv.docs_ids)
            )
              AND d.id <> l_arv_id
              AND a.jaak > 0
            ORDER BY kpv
            LOOP
                -- делаем пропорциональную оплату
                -- изем уже имеющуюся оплату
                l_doc_tasu_id = (
                    SELECT id
                    FROM docs.arvtasu
                    WHERE doc_arv_id = v_tulu_arved.id
                      AND doc_tasu_id = l_tasu_id
                      AND status <> 3
                    ORDER BY id DESC
                    LIMIT 1
                );

                -- готовим параметры
                l_tasu_summa = CASE WHEN v_tulu_arved.jaak > l_summa THEN l_summa ELSE v_tulu_arved.jaak END;
                SELECT coalesce(l_doc_tasu_id, 0) AS id,
                       v_tasu.rekvid              AS rekvid,
                       v_tulu_arved.id            AS doc_arv_id,
                       v_tasu.maksepaev :: DATE   AS kpv,
                       l_tasu_type                AS pankkassa,
                       -- 1 - mk, 2- kassa, 3 - lausend
                       l_tasu_id                  AS doc_tasu_id,
                       l_tasu_summa               AS summa
                INTO v_params;

                SELECT row_to_json(row)
                INTO json_object
                FROM (SELECT coalesce(l_doc_tasu_id, 0) AS id,
                             v_params                   AS data) row;
                -- созранение
                l_doc_id = docs.sp_salvesta_arvtasu(json_object :: JSON, l_user_id, v_tasu.rekvid);

                l_summa = l_summa - l_tasu_summa;
                IF l_summa <= 0
                THEN
                    -- вся оплата списана, вызодим их оплат
                    EXIT;
                END IF;

            END LOOP;

    END IF;
    -- сальдо платежа
    IF l_tasu_type = 1
    THEN
        PERFORM docs.sp_update_mk_jaak(l_tasu_id);
    END IF;

    RETURN l_doc_id;

END;
$$;


ALTER FUNCTION docs.sp_tasu_arv(l_tasu_id integer, l_arv_id integer, l_user_id integer, tasu_summa numeric) OWNER TO postgres;

--
-- TOC entry 326 (class 1255 OID 180349)
-- Name: sp_update_arv_jaak(integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_update_arv_jaak(l_arv_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    l_arv_summa       NUMERIC(12, 4);
    l_tasu_summa      NUMERIC(12, 4);
    l_jaak            NUMERIC(12, 4);
    l_status          INTEGER;
    l_kpv             DATE;
    DOC_STATUS_CLOSED INTEGER = 2; -- документ закрыт
    DOC_STATUS_ACTIVE INTEGER = 1; -- документ подлежит редактированию
BEGIN

    SELECT coalesce(arv.summa, 0) :: NUMERIC,
           arv.jaak,
           d.status
           INTO l_arv_summa, l_jaak, l_status
    FROM docs.arv arv
             INNER JOIN docs.doc d ON d.id = arv.parentid
    WHERE d.id = l_arv_Id;

    SELECT coalesce(sum(summa) FILTER ( WHERE arvtasu.kpv <= current_date ), 0),
           coalesce(max(arvtasu.kpv), NULL :: DATE)
           INTO l_tasu_summa, l_kpv
    FROM docs.arvtasu arvtasu
    WHERE arvtasu.doc_arv_Id = l_arv_Id
      and summa <> 0
      AND arvtasu.status < 3;

    IF l_arv_summa < 0
    THEN
        -- kreeditarve
        IF l_tasu_summa < 0
        THEN
            l_jaak := -1 * ((-1 * l_arv_summa) - (-1 * l_tasu_summa));
        ELSE
            l_jaak := l_arv_summa + l_tasu_summa;
        END IF;
    ELSE
        l_jaak := l_arv_summa - l_tasu_summa;
    END IF;

    raise notice 'l_jaak %, l_arv_summa %, l_tasu_summa %', l_jaak, l_arv_summa, l_tasu_summa;
    
    UPDATE docs.arv
    SET tasud = l_kpv,
        jaak  = coalesce(l_jaak, 0)
    WHERE parentid = l_arv_Id;

    UPDATE docs.doc
    SET status = CASE
                     WHEN l_jaak = 0
                         THEN DOC_STATUS_CLOSED
                     ELSE DOC_STATUS_ACTIVE END
    WHERE id = l_arv_Id;

    RETURN l_jaak;
END;
$$;


ALTER FUNCTION docs.sp_update_arv_jaak(l_arv_id integer) OWNER TO postgres;

--
-- TOC entry 290 (class 1255 OID 172564)
-- Name: sp_update_mk_jaak(integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.sp_update_mk_jaak(l_mk_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    l_mk_summa   NUMERIC(12, 4) = (SELECT sum(summa)
                                   FROM docs.mk mk
                                            INNER JOIN docs.mk1 mk1 ON mk1.parentid = mk.id
                                   WHERE mk.parentid = l_mk_Id);
    l_tasu_summa NUMERIC(12, 4);
    l_jaak       NUMERIC(12, 4);
BEGIN

    -- суммируем сумму оплат по счетам
    SELECT sum(at.summa) INTO l_tasu_summa
    FROM docs.arvtasu at
             INNER JOIN docs.arv a ON a.parentid = at.doc_arv_id
    WHERE at.doc_tasu_id = l_mk_Id
      AND at.status <> 3
      AND (a.properties::JSONB ->> 'tyyp' IS NULL OR a.properties::JSONB ->> 'tyyp' <> 'ETTEMAKS');

    -- сальдо
    l_jaak = coalesce(l_mk_summa, 0) - coalesce(l_tasu_summa, 0);

    -- сохраним
    UPDATE docs.mk SET jaak = l_jaak WHERE parentid = l_mk_id;

    RETURN l_jaak;
END;
$$;


ALTER FUNCTION docs.sp_update_mk_jaak(l_mk_id integer) OWNER TO postgres;

--
-- TOC entry 325 (class 1255 OID 213391)
-- Name: update_last_rekl(integer); Type: FUNCTION; Schema: docs; Owner: postgres
--

CREATE FUNCTION docs.update_last_rekl(tnid integer, OUT result integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    raise notice 'tnId %', tnId;
    UPDATE docs.rekl SET last_shown = now() WHERE parentid = tnId;
    result = 1;
    RETURN;
END;
$$;


ALTER FUNCTION docs.update_last_rekl(tnid integer, OUT result integer) OWNER TO postgres;

--
-- TOC entry 311 (class 1255 OID 90797)
-- Name: sp_delete_asutus(integer, integer); Type: FUNCTION; Schema: libs; Owner: postgres
--

CREATE FUNCTION libs.sp_delete_asutus(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_doc           RECORD;
    v_dependid_docs RECORD;
    ids             INTEGER[];
    asutus_history  JSONB ;
    new_history     JSONB;
BEGIN

    SELECT a.*, u.ametnik AS user_name INTO v_doc
    FROM libs.asutus a
             LEFT OUTER JOIN ou.userid u ON u.id = userid
    WHERE a.id = doc_id;

    -- проверка на пользователя и его соответствие учреждению

    IF v_doc IS NULL
    THEN
        error_code = 6;
        error_message = 'Dokument ei leitud, docId: ' || coalesce(doc_id, 0)::TEXT;
        result = 0;
        RETURN;

    END IF;


    -- проверка на права. Предполагает наличие прописанных прав на удаление для данного пользователя в поле rigths


--	ids =  v_doc.rigths->'delete';
/*
	if not v_doc.rigths->'delete' @> jsonb_build_array(userid) then
		raise notice 'У пользователя нет прав на удаление'; 
		error_code = 4; 
		error_message = 'Ei saa kustuta dokument. Puudub õigused';
		result  = 0;
		return;

	end if;
*/
    -- Проверка на наличие связанных документов и их типов (если тип не проводка, то удалять нельзя)

/*    IF exists(
            SELECT 1
            FROM (
                     SELECT id
                     FROM docs.journal
                     WHERE asutusId = doc_id
                     UNION
                     SELECT id
                     FROM docs.arv
                     WHERE asutusid = doc_id
                     UNION
                     SELECT id
                     FROM docs.korder1
                     WHERE asutusid = doc_id
                     UNION
                     SELECT id
                     FROM docs.mk1
                     WHERE asutusId = doc_id
                     UNION
                     SELECT id
                     FROM rekl.luba
                     WHERE asutusId = doc_id
                     UNION
                     SELECT id
                     FROM palk.tooleping
                     WHERE parentid = doc_id
                 ) qry
        )
    THEN

        RAISE NOTICE 'Есть связанные доку менты. удалять нельзя';
        error_code = 3; -- Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid
        error_message = 'Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid';
        result = 0;
        RETURN;
    END IF;
*/
    -- Логгирование удаленного документа

    asutus_history = row_to_json(row.*)
                     FROM (SELECT a.*
                           FROM libs.asutus a
                           WHERE a.id = doc_id) row;

    SELECT row_to_json(row) INTO new_history
    FROM (SELECT now() AS deleted, v_doc.user_name AS user, asutus_history AS asutus) row;

    -- Установка статуса ("Удален")  и сохранение истории
    UPDATE libs.asutus SET staatus = 3 WHERE id = doc_id;

/*
	update docs.doc 
		set lastupdate = now(),
			history = coalesce(history,'[]')::jsonb || new_history,
			rekvid = v_doc.rekvid,
			status = DOC_STATUS
		where id = doc_id;	
*/
    result = 1;
    RETURN;
END;
$$;


ALTER FUNCTION libs.sp_delete_asutus(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 299 (class 1255 OID 107010)
-- Name: sp_delete_nomenclature(integer, integer); Type: FUNCTION; Schema: libs; Owner: postgres
--

CREATE FUNCTION libs.sp_delete_nomenclature(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_doc           RECORD;
    v_dependid_docs RECORD;
    ids             INTEGER[];
    nom_history     JSONB;
    new_history     JSONB;
    DOC_STATUS      INTEGER = 3; -- документ удален
BEGIN

    SELECT n.*,
           u.ametnik AS user_name
    INTO v_doc
    FROM libs.nomenklatuur n
             LEFT OUTER JOIN ou.userid u ON u.id = userid
    WHERE n.id = doc_id;

    IF v_doc IS NULL
    THEN
        error_code = 6;
        error_message = 'Dokument ei leitud, docId: ' || coalesce(doc_id, 0) :: TEXT;
        result = 0;
        RETURN;

    END IF;

    IF NOT exists(SELECT id
                  FROM ou.userid u
                  WHERE id = userid
                    AND (u.rekvid = v_doc.rekvid OR v_doc.rekvid IS NULL OR v_doc.rekvid = 0)
        )
    THEN

        error_code = 5;
        error_message = 'Kasutaja ei leitud, rekvId: ' || coalesce(v_doc.rekvid, 0) :: TEXT || ', userId:' ||
                        coalesce(userid, 0) :: TEXT;
        result = 0;
        RETURN;

    END IF;

/*    IF exists(
            SELECT 1
            FROM (
                     SELECT id
                     FROM docs.arv1
                     WHERE nomid = v_doc.id
                     UNION
                     SELECT id
                     FROM docs.korder2
                     WHERE nomid = v_doc.id
                     UNION
                     SELECT id
                     FROM docs.leping2
                     WHERE nomid = v_doc.id
                     UNION
                     SELECT id
                     FROM lapsed.lapse_kaart
                     WHERE nomid = v_doc.id
                       AND staatus <> 3
                     UNION
                     SELECT id
                     FROM docs.mk1
                     WHERE nomid = v_doc.id
                     UNION
                     SELECT id
                     FROM docs.pv_oper
                     WHERE nomid = v_doc.id
                     UNION ALL
-- lapse_grupp
                     SELECT id
                     FROM libs.library l
                     WHERE ('[]'::JSONB || jsonb_build_object('nomid', doc_id) <@ (l.properties::JSONB ->> 'teenused')::JSONB
                         OR '[]'::JSONB || jsonb_build_object('nomid', doc_id::TEXT) <@
                            (l.properties::JSONB ->> 'teenused')::JSONB)
                       AND l.library = 'LAPSE_GRUPP'
                       AND l.status <> 3
                 ) qry
        )
    THEN

        error_code = 3; -- Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid
        error_message = 'Ei saa kustuta dokument. Kustuta enne kõik seotud dokumendid';
        result = 0;
        RETURN;
    END IF;
*/
    UPDATE libs.nomenklatuur
    SET status = DOC_STATUS
    WHERE id = doc_id;

    result = 1;
    RETURN;
END;
$$;


ALTER FUNCTION libs.sp_delete_nomenclature(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 312 (class 1255 OID 90796)
-- Name: sp_salvesta_asutus(json, integer, integer); Type: FUNCTION; Schema: libs; Owner: postgres
--

CREATE FUNCTION libs.sp_salvesta_asutus(data json, userid integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    asutus_id      INTEGER;
    userName       TEXT;
    doc_id         INTEGER = data ->> 'id';
    doc_data       JSON    = data ->> 'data';
    doc_regkood    TEXT    = doc_data ->> 'regkood';
    doc_nimetus    TEXT    = doc_data ->> 'nimetus';
    doc_omvorm     TEXT    = doc_data ->> 'omvorm';
    doc_kasutaja   TEXT    = doc_data ->> 'kasutaja';
    doc_kontakt    TEXT    = doc_data ->> 'kontakt';
    doc_aadress    TEXT    = doc_data ->> 'aadress';
    doc_tp         TEXT    = doc_data ->> 'tp';
    doc_tel        TEXT    = doc_data ->> 'tel';
    doc_email      TEXT    = doc_data ->> 'email';
    doc_mark       TEXT    = doc_data ->> 'mark';
    doc_muud       TEXT    = doc_data ->> 'muud';
    doc_pank       TEXT    = doc_data ->> 'pank';
    doc_kmkr       TEXT    = doc_data ->> 'kmkr';
    doc_KEHTIVUS   DATE    = doc_data ->> 'kehtivus';
    is_import      BOOLEAN = data ->> 'import';
    doc_is_tootaja BOOLEAN = coalesce((doc_data ->> 'is_tootaja') :: BOOLEAN, FALSE);
    doc_asutus_aa  JSONB   = coalesce((doc_data ->> 'asutus_aa') :: JSONB, '[]':: JSONB);
    doc_aa         TEXT    = doc_data ->> 'aa';
    doc_palk_email TEXT    = doc_data ->> 'palk_email';
    new_properties JSONB;
    new_history    JSONB   = '[]'::JSONB;
    new_rights     JSONB;
    new_aa         JSONB;
BEGIN


    SELECT kasutaja
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;
    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    IF (doc_aa IS NOT NULL)
    THEN
        -- если задан упрощенный расч. счет, то пишем его (для модуля дети)

        SELECT row_to_json(row)
        INTO new_aa
        FROM (SELECT doc_aa AS aa, '' AS pank) row;

    END IF;


    SELECT row_to_json(row)
    INTO new_properties
    FROM (SELECT doc_kehtivus                                                              AS kehtivus,
                 doc_pank                                                                  AS pank,
                 CASE WHEN doc_id IS NULL OR doc_id = 0 THEN FALSE ELSE doc_is_tootaja END AS is_tootaja,
                 doc_palk_email                                                            AS palk_email,
                 CASE
                     WHEN doc_aa IS NOT NULL THEN '[]'::JSONB || new_aa :: JSONB
                     ELSE doc_asutus_aa :: JSONB END                                       AS asutus_aa,
                 doc_kmkr                                                                  AS kmkr) row;

    -- вставка или апдейт docs.doc

    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;
        SELECT row_to_json(row)
        INTO new_rights
        FROM (SELECT ARRAY [userId] AS "select",
                     ARRAY [userId] AS "update",
                     ARRAY [userId] AS "delete") row;

        INSERT INTO libs.asutus (rekvid, kasutaja, regkood, nimetus, omvorm, kontakt, aadress, tel, email, mark, muud,
                                 properties,
                                 tp, ajalugu)
        VALUES (user_rekvid, doc_kasutaja, doc_regkood, doc_nimetus, doc_omvorm, doc_kontakt, doc_aadress, doc_tel,
                doc_email,
                doc_mark,
                doc_muud, new_properties, coalesce(doc_tp, '800699'), new_history) RETURNING id
                   INTO asutus_id;


    ELSE
        -- history
        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;


        UPDATE libs.asutus
        SET regkood    = doc_regkood,
            nimetus    = doc_nimetus,
            kasutaja   = doc_kasutaja,
            omvorm     = doc_omvorm,
            kontakt    = doc_kontakt,
            aadress    = doc_aadress,
            tel        = doc_tel,
            email      = doc_email,
            mark       = doc_mark,
            muud       = doc_muud,
            tp         = coalesce(doc_tp, '800699'),
            properties = new_properties,
            ajalugu    = coalesce(ajalugu, '[]') :: JSONB || new_history::JSONB,
            staatus    = CASE WHEN staatus = 3 THEN 1 ELSE staatus END
        WHERE id = doc_id RETURNING id
            INTO asutus_id;

    END IF;

    RETURN asutus_id;

END;
$$;


ALTER FUNCTION libs.sp_salvesta_asutus(data json, userid integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 304 (class 1255 OID 107018)
-- Name: sp_salvesta_nomenclature(json, integer, integer); Type: FUNCTION; Schema: libs; Owner: postgres
--

CREATE FUNCTION libs.sp_salvesta_nomenclature(data json, userid integer, user_rekvid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    nom_id       INTEGER;
    userName     TEXT;
    doc_id       INTEGER = data ->> 'id';
    is_import    BOOLEAN = data ->> 'import';
    doc_data     JSON    = data ->> 'data';
    doc_kood     TEXT    = doc_data ->> 'kood';
    doc_nimetus  TEXT    = doc_data ->> 'nimetus';
    doc_dok      TEXT    = doc_data ->> 'dok';
    doc_uhik     TEXT    = doc_data ->> 'uhik';
    doc_hind     NUMERIC = coalesce((doc_data ->> 'hind') :: NUMERIC, 0);
    doc_kogus    NUMERIC = coalesce((doc_data ->> 'kogus') :: NUMERIC, 0);
    doc_formula  TEXT    = doc_data ->> 'formula';
    doc_muud     TEXT    = doc_data ->> 'muud';
    doc_vat      TEXT    = (doc_data ->> 'vat');
    doc_algoritm TEXT    = doc_data ->> 'algoritm';
    doc_valid    DATE    = CASE WHEN empty(doc_data ->> 'valid') THEN NULL::DATE ELSE (doc_data ->> 'valid')::DATE END;
    json_object  JSONB;
    new_history  JSONB;
    new_rights   JSONB;
    l_error      TEXT;

BEGIN

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;


    SELECT kasutaja
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;

    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE NOTICE 'User not found %', user;
        RETURN 0;
    END IF;


    IF (jsonb_array_length(json_object) > 0)
    THEN
        l_error = array_to_string(array_agg(value ->> 'error_message'), ',')
                  FROM (
                           SELECT *
                           FROM jsonb_array_elements(json_object)
                       ) qry;

        RAISE EXCEPTION '%',l_error;
    END IF;


    SELECT row_to_json(row)
    INTO json_object
    FROM (SELECT doc_vat      AS vat,
                 doc_algoritm AS algoritm
         ) row;

    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;
        SELECT row_to_json(row)
        INTO new_rights
        FROM (SELECT ARRAY [userId] AS "select",
                     ARRAY [userId] AS "update",
                     ARRAY [userId] AS "delete") row;

        -- uus kiri
        INSERT INTO libs.nomenklatuur (rekvid, dok, kood, nimetus, uhik, hind, muud, kogus, formula,
                                       properties)
        VALUES (user_rekvid, doc_dok, doc_kood, doc_nimetus, doc_uhik, doc_hind, doc_muud, doc_kogus,
                doc_formula,
                json_object) RETURNING id
                   INTO nom_id;


    ELSE
        -- muuda

        UPDATE libs.nomenklatuur
        SET rekvid     = CASE WHEN is_import IS NOT NULL THEN user_rekvid ELSE rekvid END,
            dok        = doc_dok,
            kood       = doc_kood,
            nimetus    = doc_nimetus,
            uhik       = doc_uhik,
            hind       = doc_hind,
            muud       = doc_muud,
            kogus      = doc_kogus,
            formula    = doc_formula,
            properties = json_object
        WHERE id = doc_id RETURNING id
            INTO nom_id;

    END IF;


    RETURN coalesce(nom_id, 0);

END;
$$;


ALTER FUNCTION libs.sp_salvesta_nomenclature(data json, userid integer, user_rekvid integer) OWNER TO postgres;

--
-- TOC entry 293 (class 1255 OID 41014)
-- Name: get_user_data(text, integer, text); Type: FUNCTION; Schema: ou; Owner: postgres
--

CREATE FUNCTION ou.get_user_data(l_kasutaja text, l_rekvid integer, l_module text DEFAULT 'lapsed'::text) RETURNS TABLE(id integer, rekvid integer, kasutaja text, ametnik text, parool text, muud text, last_login timestamp without time zone, asutus text, asutus_tais text, regkood text, aadress text, tel text, email text, allowed_access text[], allowed_libs text[], parentid integer, parent_asutus text, roles jsonb)
    LANGUAGE sql
    AS $$

SELECT u.id,
       u.rekvid,
       u.kasutaja::TEXT,
       u.ametnik::TEXT,
       u.parool::TEXT,
       u.muud,
       u.last_login,
       r.nimetus::TEXT                                                    AS asutus,
       CASE WHEN r.muud IS NOT NULL THEN r.muud ELSE r.nimetus END ::TEXT AS asutus_tais,
       r.regkood::TEXT                                                    AS regkood,
       r.aadress::TEXT                                                    AS aadress,
       r.tel::TEXT                                                        AS tel,
       r.email::TEXT                                                      AS email,
       rs.a::TEXT[]                                                       AS allowed_access,
       allowed_modules.libs::TEXT[]                                       AS allowed_libs,
       r.parentid,
       CASE
           WHEN parent_r.muud IS NOT NULL THEN parent_r.muud
           ELSE
               coalesce(parent_r.nimetus, CASE WHEN r.muud IS NOT NULL THEN r.muud ELSE r.nimetus END)
           END ::TEXT                                                     AS parent_asutus,
       u.roles

FROM ou.userid u
         JOIN ou.rekv r ON r.id = u.rekvid AND rtrim(ltrim(u.kasutaja))::TEXT = ltrim(rtrim(l_kasutaja)) and parentid < 999
         LEFT OUTER JOIN ou.rekv parent_r ON parent_r.id = r.parentid
         JOIN (
    SELECT array_agg('{"id":'::TEXT || r.id::TEXT || ',"nimetus":"'::TEXT || r.nimetus || '"}') AS a
    FROM (
             SELECT r.id, r.nimetus
             FROM ou.rekv r
                      JOIN ou.userid u_1 ON u_1.rekvid = r.id
             WHERE ltrim(rtrim(u_1.kasutaja))::TEXT = ltrim(rtrim(l_kasutaja))
               AND r.status <> 3
               AND u_1.status <> 3
         ) r) rs ON rs.a IS NOT NULL
         JOIN (
    SELECT array_agg('{"id":'::TEXT || lib.id::TEXT || ',"nimetus":"'::TEXT || lib.nimetus || '"}')
               AS libs
    FROM (
             SELECT id,
                    kood::TEXT,
                    nimetus::TEXT,
                    library::TEXT                          AS lib,
                    (properties::JSONB -> 'module')::JSONB AS module,
                    (properties::JSONB -> 'roles')::JSONB  AS roles
             FROM libs.library l
             WHERE l.library = 'DOK'
               AND status <> 3
               AND ((properties::JSONB -> 'module') @> l_module::JSONB OR l_module IS NULL)
         ) lib
) allowed_modules ON allowed_modules.libs IS NOT NULL
WHERE (r.id = l_rekvid OR l_rekvid IS NULL)
ORDER BY u.last_login DESC
LIMIT 1;

$$;


ALTER FUNCTION ou.get_user_data(l_kasutaja text, l_rekvid integer, l_module text) OWNER TO postgres;

--
-- TOC entry 313 (class 1255 OID 100261)
-- Name: kinnita_taotlus(integer, integer); Type: FUNCTION; Schema: ou; Owner: postgres
--

CREATE FUNCTION ou.kinnita_taotlus(user_id integer, l_id integer, OUT error_code integer, OUT result integer, OUT error_message text) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user      RECORD;
    v_taotlus   RECORD;
    l_asutus_id INTEGER;
    l_object_id INTEGER;
BEGIN
    -- создать пользователя
    SELECT * INTO v_user FROM ou.userid WHERE id = user_id LIMIT 1;
    SELECT * INTO v_taotlus FROM ou.taotlus_login WHERE parentid = l_id LIMIT 1;

    -- проверка
/*    IF NOT coalesce((v_user.properties ->> 'is_admin')::BOOLEAN, FALSE)
    THEN
        error_code = 4;
        error_message = 'Puudub õigused';
        result = 0;
        RETURN;

    END IF;
*/

    INSERT INTO ou.userid (rekvid, kasutaja, ametnik, parool, muud, roles)
    SELECT v_user.rekvid::INTEGER,
           v_taotlus.kasutaja,
           v_taotlus.nimi,
           '',
           v_taotlus.muud,
           '{
             "is_kasutaja": true
           }'::JSONB
    WHERE NOT exists(
            SELECT id
            FROM ou.userid
            WHERE rekvid = v_user.rekvid
              AND kasutaja = v_taotlus.kasutaja
              AND status <> 3) RETURNING id INTO result;

    -- поменять статус
    UPDATE ou.taotlus_login
    SET status = 2
    WHERE parentid = l_id;

    UPDATE docs.doc SET status = 2 WHERE id = l_id;

    -- создать клиента

    INSERT INTO libs.asutus (rekvid, regkood, nimetus, omvorm, aadress, kontakt, tel, email, kasutaja)
    VALUES (v_user.rekvid, NULL, v_taotlus.nimi, 'ISIK', v_taotlus.aadress, NULL, v_taotlus.tel, v_taotlus.email,
            v_taotlus.kasutaja) RETURNING id INTO l_asutus_id;

    -- увязываем пользователя и клиента
    INSERT INTO libs.asutus_user_id (user_id, asutus_id)
    VALUES (result, l_asutus_id);

    -- создать обьект
    INSERT INTO libs.object (rekvid, asutusid, aadress)
    VALUES (v_user.rekvid, l_asutus_id, v_taotlus.aadress) RETURNING id INTO l_object_id;

    -- связваем обьект с клиентом
    INSERT INTO libs.object_owner (object_id, asutus_id)
    VALUES (l_object_id, l_asutus_id);

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
$$;


ALTER FUNCTION ou.kinnita_taotlus(user_id integer, l_id integer, OUT error_code integer, OUT result integer, OUT error_message text) OWNER TO postgres;

--
-- TOC entry 298 (class 1255 OID 57353)
-- Name: sp_salvesta_taotlus_login(json, integer, integer); Type: FUNCTION; Schema: ou; Owner: postgres
--

CREATE FUNCTION ou.sp_salvesta_taotlus_login(data json, l_user_id integer, l_rekv_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
    l_id          INTEGER;
    doc_id        INTEGER = data ->> 'id';
    doc_data      JSON    = data ->> 'data';
    doc_kasutaja  TEXT    = doc_data ->> 'kasutaja';
    doc_parool    TEXT    = doc_data ->> 'parool';
    doc_nimi      TEXT    = doc_data ->> 'nimi';
    doc_aadress   TEXT    = doc_data ->> 'aadress';
    doc_email     TEXT    = doc_data ->> 'email';
    doc_tel       TEXT    = doc_data ->> 'tel';
    doc_muud      TEXT    = doc_data ->> 'muud';
    new_history   JSONB;
    l_props       JSONB;
    l_string      TEXT;
    l_kasutaja    TEXT;
    l_doc_type_id INTEGER = (SELECT id
                             FROM libs.library
                             WHERE library = 'DOK'
                               AND kood = 'TAOTLUS_LOGIN'
                             LIMIT 1);
BEGIN

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;

    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     doc_nimi AS user) row;

        INSERT INTO docs.doc (doc_type_id, history)
        VALUES (l_doc_type_id, new_history) RETURNING id INTO doc_id;

        INSERT INTO ou.taotlus_login (parentid, kpv, kasutaja, parool, nimi, aadress, email, tel, muud, properties,
                                      ajalugu, status)
        VALUES (doc_id, current_date, doc_kasutaja, doc_parool, doc_nimi, doc_aadress, doc_email, doc_tel, doc_muud,
                l_props,
                new_history, 1);

        SELECT currval('docs.doc_id_seq') INTO doc_id;

    ELSE

        l_kasutaja = (SELECT ametnik FROM ou.userid WHERE id = l_user_id LIMIT 1);

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()      AS updated,
                     l_kasutaja AS user,
                     u.kasutaja,
                     u.parool,
                     u.aadress,
                     u.email,
                     u.tel
              FROM ou.taotlus_login u
              WHERE u.id = doc_id) row;


        UPDATE docs.doc
        SET history    = history || new_history,
            lastupdate = now()
        WHERE id = doc_id;

        UPDATE ou.taotlus_login
        SET kasutaja   = doc_kasutaja,
            parool     = doc_parool,
            nimi       = doc_nimi,
            aadress    = doc_aadress,
            email      = doc_email,
            tel        = doc_tel,
            muud       = doc_muud,
            properties = properties::JSONB || l_props
        WHERE id = doc_id RETURNING id
            INTO l_id;
    END IF;

    RETURN doc_id;

END ;
$$;


ALTER FUNCTION ou.sp_salvesta_taotlus_login(data json, l_user_id integer, l_rekv_id integer) OWNER TO postgres;

--
-- TOC entry 301 (class 1255 OID 107015)
-- Name: empty(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.empty(date) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$

BEGIN

    IF $1 IS NULL OR year($1) < year(now()::DATE) - 100
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$_$;


ALTER FUNCTION public.empty(date) OWNER TO postgres;

--
-- TOC entry 302 (class 1255 OID 107016)
-- Name: empty(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.empty(integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$

BEGIN

    IF $1 IS NULL OR $1 = 0
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$_$;


ALTER FUNCTION public.empty(integer) OWNER TO postgres;

--
-- TOC entry 303 (class 1255 OID 107017)
-- Name: empty(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.empty(numeric) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$

BEGIN

    IF $1 IS NULL OR $1 = 0
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$_$;


ALTER FUNCTION public.empty(numeric) OWNER TO postgres;

--
-- TOC entry 300 (class 1255 OID 107014)
-- Name: empty(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.empty(character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$

BEGIN

    IF $1 IS NULL OR length(ltrim(rtrim($1))) < 1
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$_$;


ALTER FUNCTION public.empty(character varying) OWNER TO postgres;

--
-- TOC entry 292 (class 1255 OID 57354)
-- Name: format_date(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.format_date(l_kpv text) RETURNS date
    LANGUAGE plpgsql
    AS $$


DECLARE
    return_date DATE;
BEGIN
    -- format DD.MM.YYYY HH:MI:SS
    IF (SELECT l_kpv SIMILAR TO '__.__.____') or (SELECT l_kpv SIMILAR TO '__.__.____ __:__*')
    THEN
        return_date = make_date(substring(l_kpv FROM 7 FOR 4)::INTEGER, substring(l_kpv FROM 4 FOR 2)::INTEGER,
                                left(l_kpv, 2)::INTEGER);

    ELSEIF (isfinite(l_kpv::DATE))
    THEN
        return_date = l_kpv;
    END IF;

    RETURN return_date;

EXCEPTION
    WHEN OTHERS
        THEN
            RAISE NOTICE 'error % %', SQLERRM, SQLSTATE;
            RETURN NULL;

END;
$$;


ALTER FUNCTION public.format_date(l_kpv text) OWNER TO postgres;

--
-- TOC entry 297 (class 1255 OID 106599)
-- Name: month(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.month(date DEFAULT CURRENT_DATE) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN cast(extract(MONTH FROM $1) AS INT8);
END;
$_$;


ALTER FUNCTION public.month(date) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 255 (class 1259 OID 118050)
-- Name: arv; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.arv (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    userid integer NOT NULL,
    journalid integer DEFAULT 0 NOT NULL,
    doklausid integer DEFAULT 0 NOT NULL,
    liik smallint DEFAULT 0 NOT NULL,
    operid integer DEFAULT 0 NOT NULL,
    number character(20) NOT NULL,
    kpv date DEFAULT ('now'::text)::date NOT NULL,
    asutusid integer DEFAULT 0 NOT NULL,
    arvid integer DEFAULT 0 NOT NULL,
    lisa character(120) NOT NULL,
    tahtaeg date,
    kbmta numeric(12,4) DEFAULT 0 NOT NULL,
    kbm numeric(12,4) DEFAULT 0 NOT NULL,
    summa numeric(12,4) DEFAULT 0 NOT NULL,
    tasud date,
    tasudok character(254),
    muud text,
    jaak numeric(12,4) DEFAULT 0 NOT NULL,
    objektid integer DEFAULT 0 NOT NULL,
    objekt character varying(20),
    parentid integer,
    properties jsonb
);


ALTER TABLE docs.arv OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 122906)
-- Name: arv1; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.arv1 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    nomid integer NOT NULL,
    kogus numeric(18,3) DEFAULT 0 NOT NULL,
    hind numeric(12,4) DEFAULT 0 NOT NULL,
    soodus smallint DEFAULT 0 NOT NULL,
    kbm numeric(12,4) DEFAULT 0 NOT NULL,
    summa numeric(12,4) DEFAULT 0 NOT NULL,
    muud text,
    konto character varying(20),
    kbmta numeric(12,4) DEFAULT 0 NOT NULL,
    isikid integer DEFAULT 0 NOT NULL,
    tunnus character varying(20),
    proj character varying(20),
    properties jsonb
);


ALTER TABLE docs.arv1 OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 122905)
-- Name: arv1_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.arv1_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.arv1_id_seq OWNER TO postgres;

--
-- TOC entry 3876 (class 0 OID 0)
-- Dependencies: 256
-- Name: arv1_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.arv1_id_seq OWNED BY docs.arv1.id;


--
-- TOC entry 254 (class 1259 OID 118049)
-- Name: arv_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.arv_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.arv_id_seq OWNER TO postgres;

--
-- TOC entry 3878 (class 0 OID 0)
-- Dependencies: 254
-- Name: arv_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.arv_id_seq OWNED BY docs.arv.id;


--
-- TOC entry 261 (class 1259 OID 122963)
-- Name: arvtasu; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.arvtasu (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    doc_arv_id integer NOT NULL,
    doc_tasu_id integer,
    kpv date DEFAULT ('now'::text)::date NOT NULL,
    summa numeric(14,4) DEFAULT 0 NOT NULL,
    dok text,
    pankkassa smallint DEFAULT 0 NOT NULL,
    muud text,
    properties jsonb,
    status integer DEFAULT 0
);


ALTER TABLE docs.arvtasu OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 122962)
-- Name: arvtasu_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.arvtasu_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.arvtasu_id_seq OWNER TO postgres;

--
-- TOC entry 3881 (class 0 OID 0)
-- Dependencies: 260
-- Name: arvtasu_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.arvtasu_id_seq OWNED BY docs.arvtasu.id;


--
-- TOC entry 224 (class 1259 OID 49204)
-- Name: doc; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.doc (
    id integer NOT NULL,
    rekvid integer,
    docs_ids integer[],
    created timestamp without time zone DEFAULT now(),
    lastupdate timestamp without time zone DEFAULT now(),
    doc_type_id integer,
    bpm jsonb,
    history jsonb,
    status integer DEFAULT 0
);


ALTER TABLE docs.doc OWNER TO postgres;

--
-- TOC entry 3883 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN doc.docs_ids; Type: COMMENT; Schema: docs; Owner: postgres
--

COMMENT ON COLUMN docs.doc.docs_ids IS 'seotud dokumendide id';


--
-- TOC entry 3884 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN doc.doc_type_id; Type: COMMENT; Schema: docs; Owner: postgres
--

COMMENT ON COLUMN docs.doc.doc_type_id IS 'тип документа, из таблицы library.kood';


--
-- TOC entry 3885 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN doc.bpm; Type: COMMENT; Schema: docs; Owner: postgres
--

COMMENT ON COLUMN docs.doc.bpm IS 'бизнес процесс';


--
-- TOC entry 223 (class 1259 OID 49203)
-- Name: doc_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.doc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.doc_id_seq OWNER TO postgres;

--
-- TOC entry 3887 (class 0 OID 0)
-- Dependencies: 223
-- Name: doc_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.doc_id_seq OWNED BY docs.doc.id;


--
-- TOC entry 269 (class 1259 OID 172597)
-- Name: korder1; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.korder1 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    rekvid integer NOT NULL,
    userid integer NOT NULL,
    journalid integer,
    kassaid integer NOT NULL,
    tyyp integer DEFAULT 1 NOT NULL,
    doklausid integer,
    number text NOT NULL,
    kpv date DEFAULT ('now'::text)::date NOT NULL,
    asutusid integer NOT NULL,
    nimi text NOT NULL,
    aadress text,
    dokument text,
    alus text,
    summa numeric(12,4) DEFAULT 0 NOT NULL,
    muud text,
    arvid integer,
    doktyyp integer,
    dokid integer
);


ALTER TABLE docs.korder1 OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 172596)
-- Name: korder1_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.korder1_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.korder1_id_seq OWNER TO postgres;

--
-- TOC entry 3890 (class 0 OID 0)
-- Dependencies: 268
-- Name: korder1_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.korder1_id_seq OWNED BY docs.korder1.id;


--
-- TOC entry 271 (class 1259 OID 172619)
-- Name: korder2; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.korder2 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    nomid integer NOT NULL,
    nimetus text NOT NULL,
    summa numeric(12,4) DEFAULT 0 NOT NULL,
    konto character varying(20),
    tunnus character varying(20),
    proj character varying(20),
    muud text
);


ALTER TABLE docs.korder2 OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 172618)
-- Name: korder2_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.korder2_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.korder2_id_seq OWNER TO postgres;

--
-- TOC entry 3893 (class 0 OID 0)
-- Dependencies: 270
-- Name: korder2_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.korder2_id_seq OWNED BY docs.korder2.id;


--
-- TOC entry 237 (class 1259 OID 106535)
-- Name: leping1; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.leping1 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    asutusid integer NOT NULL,
    objektid integer,
    rekvid integer NOT NULL,
    number character(20) NOT NULL,
    kpv date NOT NULL,
    tahtaeg date,
    selgitus text,
    dok text,
    muud text,
    propertieds jsonb
);


ALTER TABLE docs.leping1 OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 106534)
-- Name: leping1_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.leping1_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.leping1_id_seq OWNER TO postgres;

--
-- TOC entry 3896 (class 0 OID 0)
-- Dependencies: 236
-- Name: leping1_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.leping1_id_seq OWNED BY docs.leping1.id;


--
-- TOC entry 245 (class 1259 OID 114702)
-- Name: leping2; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.leping2 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    nomid integer NOT NULL,
    kogus numeric(12,3) DEFAULT 0 NOT NULL,
    hind numeric(12,4) DEFAULT 0 NOT NULL,
    summa numeric(12,4) DEFAULT 0 NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    muud text,
    formula text,
    kbm integer DEFAULT 1 NOT NULL
);


ALTER TABLE docs.leping2 OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 114701)
-- Name: leping2_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.leping2_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.leping2_id_seq OWNER TO postgres;

--
-- TOC entry 3899 (class 0 OID 0)
-- Dependencies: 244
-- Name: leping2_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.leping2_id_seq OWNED BY docs.leping2.id;


--
-- TOC entry 265 (class 1259 OID 172393)
-- Name: mk; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.mk (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    journalid integer DEFAULT 0 NOT NULL,
    aaid integer DEFAULT 0 NOT NULL,
    doklausid integer DEFAULT 0 NOT NULL,
    kpv date DEFAULT CURRENT_DATE NOT NULL,
    maksepaev date DEFAULT CURRENT_DATE NOT NULL,
    number character varying(20) DEFAULT ''::character varying NOT NULL,
    selg text DEFAULT ''::text NOT NULL,
    viitenr character varying(20) DEFAULT ''::character varying NOT NULL,
    opt integer DEFAULT 1 NOT NULL,
    muud text,
    arvid integer DEFAULT 0 NOT NULL,
    doktyyp integer DEFAULT 0 NOT NULL,
    dokid integer DEFAULT 0 NOT NULL,
    parentid integer,
    jaak numeric(14,2) DEFAULT 0 NOT NULL,
    properties jsonb
);


ALTER TABLE docs.mk OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 172424)
-- Name: mk1; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.mk1 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    asutusid integer NOT NULL,
    nomid integer NOT NULL,
    summa numeric(12,4) DEFAULT 0 NOT NULL,
    aa character varying(20) NOT NULL,
    pank character varying(3),
    journalid integer,
    konto character varying(20),
    tp character varying(20),
    tunnus character varying(20),
    proj character varying(20)
);


ALTER TABLE docs.mk1 OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 172423)
-- Name: mk1_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.mk1_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.mk1_id_seq OWNER TO postgres;

--
-- TOC entry 3903 (class 0 OID 0)
-- Dependencies: 266
-- Name: mk1_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.mk1_id_seq OWNED BY docs.mk1.id;


--
-- TOC entry 264 (class 1259 OID 172392)
-- Name: mk_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.mk_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.mk_id_seq OWNER TO postgres;

--
-- TOC entry 3905 (class 0 OID 0)
-- Dependencies: 264
-- Name: mk_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.mk_id_seq OWNED BY docs.mk.id;


--
-- TOC entry 248 (class 1259 OID 114741)
-- Name: moodu1; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.moodu1 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    lepingid integer,
    kpv date NOT NULL,
    muud text,
    propertieds jsonb
);


ALTER TABLE docs.moodu1 OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 114740)
-- Name: moodu1_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.moodu1_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.moodu1_id_seq OWNER TO postgres;

--
-- TOC entry 3908 (class 0 OID 0)
-- Dependencies: 247
-- Name: moodu1_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.moodu1_id_seq OWNED BY docs.moodu1.id;


--
-- TOC entry 250 (class 1259 OID 114758)
-- Name: moodu2; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.moodu2 (
    id integer NOT NULL,
    parentid integer NOT NULL,
    nomid integer NOT NULL,
    kogus numeric(12,3) DEFAULT 0 NOT NULL,
    muud text,
    properties jsonb
);


ALTER TABLE docs.moodu2 OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 114757)
-- Name: moodu2_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.moodu2_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.moodu2_id_seq OWNER TO postgres;

--
-- TOC entry 3911 (class 0 OID 0)
-- Dependencies: 249
-- Name: moodu2_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.moodu2_id_seq OWNED BY docs.moodu2.id;


--
-- TOC entry 278 (class 1259 OID 196758)
-- Name: rekl; Type: TABLE; Schema: docs; Owner: postgres
--

CREATE TABLE docs.rekl (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    parentid integer,
    asutusid integer,
    alg_kpv date,
    lopp_kpv date,
    nimetus text,
    link text,
    muud text,
    properties jsonb,
    "timestamp" timestamp without time zone DEFAULT LOCALTIMESTAMP NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    ajalugu jsonb,
    last_shown timestamp without time zone
);


ALTER TABLE docs.rekl OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 196757)
-- Name: rekl_id_seq; Type: SEQUENCE; Schema: docs; Owner: postgres
--

CREATE SEQUENCE docs.rekl_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE docs.rekl_id_seq OWNER TO postgres;

--
-- TOC entry 3914 (class 0 OID 0)
-- Dependencies: 277
-- Name: rekl_id_seq; Type: SEQUENCE OWNED BY; Schema: docs; Owner: postgres
--

ALTER SEQUENCE docs.rekl_id_seq OWNED BY docs.rekl.id;


--
-- TOC entry 230 (class 1259 OID 90784)
-- Name: asutus; Type: TABLE; Schema: libs; Owner: postgres
--

CREATE TABLE libs.asutus (
    id integer NOT NULL,
    rekvid integer,
    regkood character(20),
    nimetus character(254) NOT NULL,
    omvorm character(20),
    aadress text,
    kontakt text,
    tel character(60),
    faks character(60),
    email character(60),
    muud text,
    tp character varying(20),
    staatus integer DEFAULT 1,
    mark text,
    properties jsonb,
    ajalugi jsonb,
    kasutaja text
);


ALTER TABLE libs.asutus OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 90783)
-- Name: asutus_id_seq; Type: SEQUENCE; Schema: libs; Owner: postgres
--

CREATE SEQUENCE libs.asutus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE libs.asutus_id_seq OWNER TO postgres;

--
-- TOC entry 3917 (class 0 OID 0)
-- Dependencies: 229
-- Name: asutus_id_seq; Type: SEQUENCE OWNED BY; Schema: libs; Owner: postgres
--

ALTER SEQUENCE libs.asutus_id_seq OWNED BY libs.asutus.id;


--
-- TOC entry 233 (class 1259 OID 98334)
-- Name: asutus_user_id; Type: TABLE; Schema: libs; Owner: postgres
--

CREATE TABLE libs.asutus_user_id (
    id integer NOT NULL,
    user_id integer,
    asutus_id integer,
    properties jsonb
);


ALTER TABLE libs.asutus_user_id OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 98333)
-- Name: asutus_user_id_id_seq; Type: SEQUENCE; Schema: libs; Owner: postgres
--

CREATE SEQUENCE libs.asutus_user_id_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE libs.asutus_user_id_id_seq OWNER TO postgres;

--
-- TOC entry 3920 (class 0 OID 0)
-- Dependencies: 232
-- Name: asutus_user_id_id_seq; Type: SEQUENCE OWNED BY; Schema: libs; Owner: postgres
--

ALTER SEQUENCE libs.asutus_user_id_id_seq OWNED BY libs.asutus_user_id.id;


--
-- TOC entry 239 (class 1259 OID 106578)
-- Name: dokprop; Type: TABLE; Schema: libs; Owner: postgres
--

CREATE TABLE libs.dokprop (
    id integer NOT NULL,
    parentid integer NOT NULL,
    registr smallint DEFAULT 1 NOT NULL,
    vaatalaus smallint DEFAULT 0 NOT NULL,
    selg text NOT NULL,
    muud text,
    asutusid integer,
    details jsonb,
    proc_ text,
    tyyp integer DEFAULT 1 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    rekvid integer
);


ALTER TABLE libs.dokprop OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 106577)
-- Name: dokprop_id_seq; Type: SEQUENCE; Schema: libs; Owner: postgres
--

CREATE SEQUENCE libs.dokprop_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE libs.dokprop_id_seq OWNER TO postgres;

--
-- TOC entry 3923 (class 0 OID 0)
-- Dependencies: 238
-- Name: dokprop_id_seq; Type: SEQUENCE OWNED BY; Schema: libs; Owner: postgres
--

ALTER SEQUENCE libs.dokprop_id_seq OWNED BY libs.dokprop.id;


--
-- TOC entry 220 (class 1259 OID 40996)
-- Name: library; Type: TABLE; Schema: libs; Owner: postgres
--

CREATE TABLE libs.library (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    kood character(20) DEFAULT ''::bpchar NOT NULL,
    nimetus character(254) DEFAULT ''::bpchar NOT NULL,
    library character(20) DEFAULT ''::bpchar NOT NULL,
    muud text,
    properties jsonb,
    "timestamp" timestamp without time zone DEFAULT LOCALTIMESTAMP NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    ajalugu jsonb
);


ALTER TABLE libs.library OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 40995)
-- Name: library_id_seq; Type: SEQUENCE; Schema: libs; Owner: postgres
--

CREATE SEQUENCE libs.library_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE libs.library_id_seq OWNER TO postgres;

--
-- TOC entry 3925 (class 0 OID 0)
-- Dependencies: 219
-- Name: library_id_seq; Type: SEQUENCE OWNED BY; Schema: libs; Owner: postgres
--

ALTER SEQUENCE libs.library_id_seq OWNED BY libs.library.id;


--
-- TOC entry 241 (class 1259 OID 106601)
-- Name: nomenklatuur; Type: TABLE; Schema: libs; Owner: postgres
--

CREATE TABLE libs.nomenklatuur (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    dok text NOT NULL,
    kood character(20) NOT NULL,
    nimetus text NOT NULL,
    uhik text,
    hind numeric(12,4) DEFAULT 0 NOT NULL,
    muud text,
    kogus numeric(12,3) DEFAULT 0 NOT NULL,
    formula text,
    status integer DEFAULT 0 NOT NULL,
    properties jsonb
);


ALTER TABLE libs.nomenklatuur OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 106600)
-- Name: nomenklatuur_id_seq; Type: SEQUENCE; Schema: libs; Owner: postgres
--

CREATE SEQUENCE libs.nomenklatuur_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE libs.nomenklatuur_id_seq OWNER TO postgres;

--
-- TOC entry 3927 (class 0 OID 0)
-- Dependencies: 240
-- Name: nomenklatuur_id_seq; Type: SEQUENCE OWNED BY; Schema: libs; Owner: postgres
--

ALTER SEQUENCE libs.nomenklatuur_id_seq OWNED BY libs.nomenklatuur.id;


--
-- TOC entry 228 (class 1259 OID 90757)
-- Name: object; Type: TABLE; Schema: libs; Owner: postgres
--

CREATE TABLE libs.object (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    asutusid integer,
    aadress text,
    muud text,
    properties jsonb,
    "timestamp" timestamp without time zone DEFAULT LOCALTIMESTAMP NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    ajalugu jsonb
);


ALTER TABLE libs.object OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 90756)
-- Name: object_id_seq; Type: SEQUENCE; Schema: libs; Owner: postgres
--

CREATE SEQUENCE libs.object_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE libs.object_id_seq OWNER TO postgres;

--
-- TOC entry 3930 (class 0 OID 0)
-- Dependencies: 227
-- Name: object_id_seq; Type: SEQUENCE OWNED BY; Schema: libs; Owner: postgres
--

ALTER SEQUENCE libs.object_id_seq OWNED BY libs.object.id;


--
-- TOC entry 235 (class 1259 OID 98344)
-- Name: object_owner; Type: TABLE; Schema: libs; Owner: postgres
--

CREATE TABLE libs.object_owner (
    id integer NOT NULL,
    object_id integer,
    asutus_id integer,
    properties jsonb
);


ALTER TABLE libs.object_owner OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 98343)
-- Name: object_owner_id_seq; Type: SEQUENCE; Schema: libs; Owner: postgres
--

CREATE SEQUENCE libs.object_owner_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE libs.object_owner_id_seq OWNER TO postgres;

--
-- TOC entry 3933 (class 0 OID 0)
-- Dependencies: 234
-- Name: object_owner_id_seq; Type: SEQUENCE OWNED BY; Schema: libs; Owner: postgres
--

ALTER SEQUENCE libs.object_owner_id_seq OWNED BY libs.object_owner.id;


--
-- TOC entry 253 (class 1259 OID 118036)
-- Name: aa; Type: TABLE; Schema: ou; Owner: postgres
--

CREATE TABLE ou.aa (
    id integer NOT NULL,
    parentid integer NOT NULL,
    arve character(20) NOT NULL,
    nimetus character(254) NOT NULL,
    saldo numeric(12,4) DEFAULT 0 NOT NULL,
    default_ smallint DEFAULT 0 NOT NULL,
    kassa integer DEFAULT 0 NOT NULL,
    pank integer DEFAULT 0 NOT NULL,
    konto character(20),
    muud text,
    tp character varying(20)
);


ALTER TABLE ou.aa OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 118035)
-- Name: aa_id_seq; Type: SEQUENCE; Schema: ou; Owner: postgres
--

CREATE SEQUENCE ou.aa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ou.aa_id_seq OWNER TO postgres;

--
-- TOC entry 3936 (class 0 OID 0)
-- Dependencies: 252
-- Name: aa_id_seq; Type: SEQUENCE OWNED BY; Schema: ou; Owner: postgres
--

ALTER SEQUENCE ou.aa_id_seq OWNED BY ou.aa.id;


--
-- TOC entry 259 (class 1259 OID 122943)
-- Name: config; Type: TABLE; Schema: ou; Owner: postgres
--

CREATE TABLE ou.config (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    keel integer DEFAULT 1 NOT NULL,
    toolbar1 integer DEFAULT 0 NOT NULL,
    toolbar2 integer DEFAULT 0 NOT NULL,
    toolbar3 integer DEFAULT 0 NOT NULL,
    number character varying(20) DEFAULT ''::character varying NOT NULL,
    arvround numeric(5,2) DEFAULT 0.1 NOT NULL,
    asutusid integer DEFAULT 0 NOT NULL,
    tahtpaev integer DEFAULT 0,
    www1 character varying(254) DEFAULT ''::character varying,
    dokprop1 integer DEFAULT 0,
    dokprop2 integer DEFAULT 0,
    propertis jsonb
);


ALTER TABLE ou.config OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 122942)
-- Name: config_id_seq; Type: SEQUENCE; Schema: ou; Owner: postgres
--

CREATE SEQUENCE ou.config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ou.config_id_seq OWNER TO postgres;

--
-- TOC entry 3938 (class 0 OID 0)
-- Dependencies: 258
-- Name: config_id_seq; Type: SEQUENCE OWNED BY; Schema: ou; Owner: postgres
--

ALTER SEQUENCE ou.config_id_seq OWNED BY ou.config.id;


--
-- TOC entry 215 (class 1259 OID 32807)
-- Name: rekv; Type: TABLE; Schema: ou; Owner: postgres
--

CREATE TABLE ou.rekv (
    id integer NOT NULL,
    parentid integer,
    regkood character(20) NOT NULL,
    nimetus text NOT NULL,
    kbmkood character(20),
    aadress text,
    haldus text,
    tel text,
    faks text,
    email text,
    juht text,
    raama text,
    muud text,
    properties jsonb,
    ajalugu jsonb,
    status integer DEFAULT 1
);


ALTER TABLE ou.rekv OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 32792)
-- Name: userid; Type: TABLE; Schema: ou; Owner: postgres
--

CREATE TABLE ou.userid (
    id integer NOT NULL,
    rekvid integer NOT NULL,
    kasutaja character(50) NOT NULL,
    ametnik character(254) NOT NULL,
    parool text,
    muud text,
    last_login timestamp without time zone DEFAULT now() NOT NULL,
    properties jsonb,
    roles jsonb,
    ajalugu jsonb,
    status integer DEFAULT 0
);


ALTER TABLE ou.userid OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 40970)
-- Name: cur_userid; Type: VIEW; Schema: ou; Owner: postgres
--

CREATE VIEW ou.cur_userid AS
 SELECT u.id,
    r.nimetus AS asutus,
    u.kasutaja,
    u.ametnik,
    (u.properties ->> 'email'::text) AS email,
    ((u.roles ->> 'is_admin'::text))::boolean AS is_admin,
    ((u.roles ->> 'is_kasutaja'::text))::boolean AS is_kasutaja,
    ((u.roles ->> 'is_raama'::text))::boolean AS is_raama,
    ((u.roles ->> 'is_juht'::text))::boolean AS is_juht,
    u.rekvid
   FROM (ou.userid u
     JOIN ou.rekv r ON ((r.id = u.rekvid)))
  WHERE (u.status <> 3);


ALTER TABLE ou.cur_userid OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 32806)
-- Name: rekv_id_seq; Type: SEQUENCE; Schema: ou; Owner: postgres
--

CREATE SEQUENCE ou.rekv_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ou.rekv_id_seq OWNER TO postgres;

--
-- TOC entry 3942 (class 0 OID 0)
-- Dependencies: 214
-- Name: rekv_id_seq; Type: SEQUENCE OWNED BY; Schema: ou; Owner: postgres
--

ALTER SEQUENCE ou.rekv_id_seq OWNED BY ou.rekv.id;


--
-- TOC entry 222 (class 1259 OID 49192)
-- Name: taotlus_login; Type: TABLE; Schema: ou; Owner: postgres
--

CREATE TABLE ou.taotlus_login (
    id integer NOT NULL,
    parentid integer NOT NULL,
    kpv date DEFAULT CURRENT_DATE NOT NULL,
    kasutaja text NOT NULL,
    parool text,
    nimi character(254) NOT NULL,
    aadress text,
    email text,
    tel text,
    muud text,
    properties jsonb,
    ajalugu jsonb,
    status integer DEFAULT 1
);


ALTER TABLE ou.taotlus_login OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 49191)
-- Name: taotlus_login_id_seq; Type: SEQUENCE; Schema: ou; Owner: postgres
--

CREATE SEQUENCE ou.taotlus_login_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ou.taotlus_login_id_seq OWNER TO postgres;

--
-- TOC entry 3945 (class 0 OID 0)
-- Dependencies: 221
-- Name: taotlus_login_id_seq; Type: SEQUENCE OWNED BY; Schema: ou; Owner: postgres
--

ALTER SEQUENCE ou.taotlus_login_id_seq OWNED BY ou.taotlus_login.id;


--
-- TOC entry 212 (class 1259 OID 32791)
-- Name: userid_id_seq; Type: SEQUENCE; Schema: ou; Owner: postgres
--

CREATE SEQUENCE ou.userid_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ou.userid_id_seq OWNER TO postgres;

--
-- TOC entry 3947 (class 0 OID 0)
-- Dependencies: 212
-- Name: userid_id_seq; Type: SEQUENCE OWNED BY; Schema: ou; Owner: postgres
--

ALTER SEQUENCE ou.userid_id_seq OWNED BY ou.userid.id;


--
-- TOC entry 262 (class 1259 OID 123156)
-- Name: arv_1_number; Type: SEQUENCE; Schema: public; Owner: db
--

CREATE SEQUENCE public.arv_1_number
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.arv_1_number OWNER TO db;

--
-- TOC entry 275 (class 1259 OID 180339)
-- Name: com_arved; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.com_arved AS
 SELECT d.id,
    arv.id AS arv_id,
    arv.number,
    to_char((arv.kpv)::timestamp with time zone, 'DD.MM.YYYY'::text) AS kpv,
    arv.summa,
    arv.liik,
    ((rtrim((asutus.nimetus)::text) || ' '::text) || ((rtrim((asutus.omvorm)::text))::character varying(120))::text) AS asutus,
    arv.asutusid,
    arv.arvid,
    arv.tasudok,
    arv.tasud,
    arv.rekvid,
    arv.jaak,
    CURRENT_DATE AS valid
   FROM ((docs.doc d
     JOIN docs.arv arv ON ((d.id = arv.parentid)))
     JOIN libs.asutus asutus ON ((asutus.id = arv.asutusid)))
  ORDER BY arv.number;


ALTER TABLE public.com_arved OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 180351)
-- Name: com_asutused; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.com_asutused AS
 SELECT qry.id,
    qry.regkood,
    qry.nimetus,
    qry.tp,
    qry.email,
    qry.kehtivus,
    qry.aadress,
    qry.kontakt,
    qry.tel,
    qry.omvorm,
    qry.pank
   FROM ( SELECT 0 AS id,
            ''::character varying(20) AS regkood,
            ''::character varying(254) AS nimetus,
            ''::character varying(20) AS tp,
            ''::character varying(254) AS email,
            (CURRENT_DATE + '100 years'::interval) AS kehtivus,
            ''::text AS aadress,
            ''::text AS kontakt,
            ''::character varying(120) AS tel,
            ''::character varying(20) AS omvorm,
            ''::character varying(20) AS pank
        UNION
         SELECT asutus.id,
            btrim((asutus.regkood)::text) AS regkood,
            (btrim((asutus.nimetus)::text))::character varying(254) AS nimetus,
            asutus.tp,
            asutus.email,
            (CURRENT_DATE + '100 years'::interval) AS kehtivus,
            asutus.aadress,
            asutus.kontakt,
            asutus.tel,
            asutus.omvorm,
            ((((asutus.properties -> 'asutus_aa'::text) -> 0) ->> 'aa'::text))::character varying(20) AS pank
           FROM libs.asutus asutus
          WHERE (asutus.staatus <> 3)) qry
  ORDER BY qry.nimetus;


ALTER TABLE public.com_asutused OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 106868)
-- Name: com_nomenclature; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.com_nomenclature AS
 SELECT qry.id,
    qry.rekvid,
    qry.kood,
    qry.nimetus,
    qry.dok,
    qry.vat,
    qry.hind,
    qry.uhik,
    qry.kogus,
    qry.konto,
    qry.formula,
    qry.valid
   FROM ( SELECT 0 AS id,
            NULL::integer AS rekvid,
            ''::character varying(20) AS kood,
            ''::character varying(20) AS nimetus,
            'DOK'::character varying(20) AS dok,
            (0)::character varying(10) AS vat,
            (0)::numeric(14,2) AS hind,
            'muud'::text AS uhik,
            (0)::numeric(14,4) AS kogus,
            ''::character varying(20) AS konto,
            ''::text AS formula,
            NULL::date AS valid
        UNION
         SELECT n.id,
            n.rekvid,
            (TRIM(BOTH FROM n.kood))::character varying(20) AS kood,
            (TRIM(BOTH FROM n.nimetus))::character varying(254) AS nimetus,
            (TRIM(BOTH FROM n.dok))::character varying(20) AS dok,
            ((n.properties ->> 'vat'::text))::character varying(10) AS vat,
            n.hind,
            n.uhik,
            n.kogus,
            COALESCE(((n.properties ->> 'konto'::text))::character varying(20), ''::character varying) AS konto,
            COALESCE((n.properties ->> 'formula'::text), ''::text) AS formula,
            ((n.properties ->> 'valid'::text))::date AS valid
           FROM libs.nomenklatuur n
          WHERE (n.status <> 3)) qry
  ORDER BY qry.kood;


ALTER TABLE public.com_nomenclature OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 106773)
-- Name: com_objekt; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.com_objekt AS
 SELECT qry.id,
    qry.kood,
    qry.nimetus,
    qry.rekvid,
    qry.asutus_id
   FROM ( SELECT 0 AS id,
            ''::character varying(20) AS kood,
            ''::character varying(20) AS nimetus,
            0 AS rekvid,
            NULL::integer AS asutus_id
        UNION
         SELECT o.id,
            ''::character varying AS kood,
            o.aadress AS nimetus,
            o.rekvid,
            oo.asutus_id
           FROM (libs.object o
             JOIN libs.object_owner oo ON ((o.id = oo.object_id)))
          WHERE (o.status <> 3)) qry
  ORDER BY qry.kood;


ALTER TABLE public.com_objekt OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 123169)
-- Name: cur_arved; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cur_arved AS
 SELECT d.id,
    d.docs_ids,
    a.id AS arv_id,
    TRIM(BOTH FROM a.number) AS number,
    a.rekvid,
    a.kpv,
    a.summa,
    a.tahtaeg,
    a.jaak,
    a.tasud,
    a.tasudok,
    a.userid,
    a.asutusid,
    a.journalid,
    a.liik,
    a.lisa,
    a.operid,
    COALESCE(a.objektid, 0) AS objektid,
    TRIM(BOTH FROM asutus.nimetus) AS asutus,
    TRIM(BOTH FROM asutus.regkood) AS regkood,
    TRIM(BOTH FROM asutus.omvorm) AS omvorm,
    TRIM(BOTH FROM asutus.aadress) AS aadress,
    TRIM(BOTH FROM asutus.email) AS email,
    (COALESCE(a.objekt, ''::character varying))::character varying(20) AS objekt,
    (COALESCE(u.ametnik, ''::bpchar))::character varying(120) AS ametnik,
    COALESCE(a.muud, ''::text) AS markused,
    ((a.properties ->> 'aa'::text))::character varying(120) AS arve,
    ((a.properties ->> 'viitenr'::text))::character varying(120) AS viitenr
   FROM (((docs.doc d
     JOIN docs.arv a ON ((a.parentid = d.id)))
     LEFT JOIN libs.asutus asutus ON ((a.asutusid = asutus.id)))
     LEFT JOIN ou.userid u ON ((u.id = a.userid)))
  ORDER BY d.lastupdate DESC;


ALTER TABLE public.cur_arved OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 90960)
-- Name: cur_asutused; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cur_asutused AS
 SELECT a.id,
    a.regkood,
    a.nimetus,
    a.omvorm,
    a.aadress,
    a.tp,
    (COALESCE(a.email, ''::bpchar))::character varying(254) AS email,
    a.mark,
    (COALESCE((((a.properties ->> 'kehtivus'::text))::date)::timestamp without time zone, (CURRENT_DATE + '10 years'::interval)))::date AS kehtivus,
    a.staatus
   FROM libs.asutus a
  WHERE (a.staatus <> 3);


ALTER TABLE public.cur_asutused OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 173487)
-- Name: cur_korder; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cur_korder AS
 SELECT d.id,
    d.rekvid,
    k.kpv,
    (TRIM(BOTH FROM k.number))::character varying(20) AS number,
    (
        CASE
            WHEN public.empty((k.nimi)::character varying) THEN (COALESCE(a.nimetus, ''::bpchar))::text
            ELSE k.nimi
        END)::character varying(254) AS nimi,
    TRIM(BOTH FROM k.dokument) AS dokument,
    k.tyyp,
    (
        CASE
            WHEN (k.tyyp = 1) THEN k2.summa
            ELSE (0)::numeric
        END)::numeric(14,2) AS deebet,
    (
        CASE
            WHEN (k.tyyp = 2) THEN k2.summa
            ELSE (0)::numeric
        END)::numeric(14,2) AS kreedit,
    aa.konto AS akonto,
    aa.nimetus AS kassa,
    (
        CASE
            WHEN (k.tyyp = 1) THEN (aa.konto)::character varying
            ELSE k2.konto
        END)::character varying(20) AS db,
    (
        CASE
            WHEN (k.tyyp = 1) THEN (k2.konto)::bpchar
            ELSE aa.konto
        END)::character varying(20) AS kr
   FROM ((((docs.doc d
     JOIN docs.korder1 k ON ((d.id = k.parentid)))
     JOIN docs.korder2 k2 ON ((k.id = k2.parentid)))
     LEFT JOIN ou.aa aa ON (((k.kassaid = aa.id) AND (aa.parentid = k.rekvid))))
     LEFT JOIN libs.asutus a ON ((k.asutusid = a.id)));


ALTER TABLE public.cur_korder OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 114724)
-- Name: cur_lepingud; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cur_lepingud AS
 SELECT d.id,
    l.rekvid,
    l.number,
    l.kpv,
    l.tahtaeg,
    l.selgitus,
    a.nimetus AS asutus,
    l.asutusid,
    l.objektid,
    o.aadress AS objekt
   FROM (((docs.doc d
     JOIN docs.leping1 l ON ((l.parentid = d.id)))
     JOIN libs.asutus a ON ((l.asutusid = a.id)))
     LEFT JOIN libs.object o ON ((o.id = l.objektid)));


ALTER TABLE public.cur_lepingud OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 116153)
-- Name: cur_moodu; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cur_moodu AS
 SELECT d.id,
    d.rekvid,
    l1.number,
    m.kpv,
    (a.nimetus)::text AS asutus,
    l1.asutusid,
    l1.objektid,
    m.lepingid,
    o.aadress AS objekt,
    array_to_string(m2.moodu, ','::text) AS moodu
   FROM (((((docs.doc d
     JOIN docs.moodu1 m ON ((m.parentid = d.id)))
     JOIN ( SELECT m2_1.parentid,
            array_agg((((((n.kood)::text || '-'::text) || (m2_1.kogus)::text) || ' '::text) || n.uhik)) AS moodu
           FROM (docs.moodu2 m2_1
             JOIN libs.nomenklatuur n ON ((n.id = m2_1.nomid)))
          GROUP BY m2_1.parentid) m2 ON ((m.id = m2.parentid)))
     JOIN docs.leping1 l1 ON ((l1.parentid = m.lepingid)))
     JOIN libs.asutus a ON ((l1.asutusid = a.id)))
     JOIN libs.object o ON ((o.id = l1.objektid)));


ALTER TABLE public.cur_moodu OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 172698)
-- Name: cur_pank; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cur_pank AS
 SELECT d.id,
    mk.rekvid,
    mk1.journalid,
    mk.kpv,
    mk.maksepaev,
    mk.number,
    mk.selg,
    mk.opt,
        CASE
            WHEN (mk.opt = 2) THEN mk1.summa
            ELSE (0)::numeric(14,2)
        END AS deebet,
        CASE
            WHEN ((mk.opt = 1) OR (COALESCE(mk.opt, 0) = 0)) THEN mk1.summa
            ELSE (0)::numeric(14,2)
        END AS kreedit,
    a.id AS asutusid,
    (COALESCE(a.regkood, ''::bpchar))::character varying(20) AS regkood,
    (COALESCE(a.nimetus, ''::bpchar))::character varying(254) AS nimetus,
    (COALESCE(n.kood, ''::bpchar))::character varying(20) AS kood,
    (COALESCE(aa.arve, ''::bpchar))::character varying(20) AS aa
   FROM (((((docs.doc d
     JOIN docs.mk mk ON ((mk.parentid = d.id)))
     JOIN docs.mk1 mk1 ON ((mk.id = mk1.parentid)))
     LEFT JOIN libs.asutus a ON ((mk1.asutusid = a.id)))
     LEFT JOIN libs.nomenklatuur n ON ((mk1.nomid = n.id)))
     LEFT JOIN ou.aa aa ON ((mk.aaid = aa.id)));


ALTER TABLE public.cur_pank OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 32824)
-- Name: cur_rekv; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cur_rekv AS
 SELECT r.id,
    r.regkood,
    r.parentid,
    r.nimetus,
    r.status
   FROM ou.rekv r
  WHERE (((r.parentid < 999) OR (r.status <> 3)) AND (r.id <> 90))
  ORDER BY r.regkood;


ALTER TABLE public.cur_rekv OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 32828)
-- Name: session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.session OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 172742)
-- Name: smk_1_number; Type: SEQUENCE; Schema: public; Owner: db
--

CREATE SEQUENCE public.smk_1_number
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.smk_1_number OWNER TO db;

--
-- TOC entry 226 (class 1259 OID 65939)
-- Name: v_taotlus; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.v_taotlus (
    id integer,
    parentid integer,
    kpv date,
    kasutaja text,
    parool text,
    nimi character(254),
    aadress text,
    email text,
    tel text,
    muud text,
    properties jsonb,
    ajalugu jsonb,
    status integer
);


ALTER TABLE public.v_taotlus OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 65932)
-- Name: v_user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.v_user (
    id integer,
    rekvid integer,
    kasutaja character(50),
    ametnik character(254),
    parool text,
    muud text,
    last_login timestamp without time zone,
    properties jsonb,
    roles jsonb,
    ajalugu jsonb,
    status integer
);


ALTER TABLE public.v_user OWNER TO postgres;

--
-- TOC entry 3441 (class 2604 OID 118053)
-- Name: arv id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.arv ALTER COLUMN id SET DEFAULT nextval('docs.arv_id_seq'::regclass);


--
-- TOC entry 3457 (class 2604 OID 122909)
-- Name: arv1 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.arv1 ALTER COLUMN id SET DEFAULT nextval('docs.arv1_id_seq'::regclass);


--
-- TOC entry 3474 (class 2604 OID 122966)
-- Name: arvtasu id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.arvtasu ALTER COLUMN id SET DEFAULT nextval('docs.arvtasu_id_seq'::regclass);


--
-- TOC entry 3406 (class 2604 OID 49207)
-- Name: doc id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.doc ALTER COLUMN id SET DEFAULT nextval('docs.doc_id_seq'::regclass);


--
-- TOC entry 3495 (class 2604 OID 172600)
-- Name: korder1 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.korder1 ALTER COLUMN id SET DEFAULT nextval('docs.korder1_id_seq'::regclass);


--
-- TOC entry 3499 (class 2604 OID 172622)
-- Name: korder2 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.korder2 ALTER COLUMN id SET DEFAULT nextval('docs.korder2_id_seq'::regclass);


--
-- TOC entry 3417 (class 2604 OID 106538)
-- Name: leping1 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.leping1 ALTER COLUMN id SET DEFAULT nextval('docs.leping1_id_seq'::regclass);


--
-- TOC entry 3427 (class 2604 OID 114705)
-- Name: leping2 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.leping2 ALTER COLUMN id SET DEFAULT nextval('docs.leping2_id_seq'::regclass);


--
-- TOC entry 3479 (class 2604 OID 172396)
-- Name: mk id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.mk ALTER COLUMN id SET DEFAULT nextval('docs.mk_id_seq'::regclass);


--
-- TOC entry 3493 (class 2604 OID 172427)
-- Name: mk1 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.mk1 ALTER COLUMN id SET DEFAULT nextval('docs.mk1_id_seq'::regclass);


--
-- TOC entry 3433 (class 2604 OID 114744)
-- Name: moodu1 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.moodu1 ALTER COLUMN id SET DEFAULT nextval('docs.moodu1_id_seq'::regclass);


--
-- TOC entry 3434 (class 2604 OID 114761)
-- Name: moodu2 id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.moodu2 ALTER COLUMN id SET DEFAULT nextval('docs.moodu2_id_seq'::regclass);


--
-- TOC entry 3501 (class 2604 OID 196761)
-- Name: rekl id; Type: DEFAULT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.rekl ALTER COLUMN id SET DEFAULT nextval('docs.rekl_id_seq'::regclass);


--
-- TOC entry 3413 (class 2604 OID 90787)
-- Name: asutus id; Type: DEFAULT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.asutus ALTER COLUMN id SET DEFAULT nextval('libs.asutus_id_seq'::regclass);


--
-- TOC entry 3415 (class 2604 OID 98337)
-- Name: asutus_user_id id; Type: DEFAULT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.asutus_user_id ALTER COLUMN id SET DEFAULT nextval('libs.asutus_user_id_id_seq'::regclass);


--
-- TOC entry 3418 (class 2604 OID 106581)
-- Name: dokprop id; Type: DEFAULT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.dokprop ALTER COLUMN id SET DEFAULT nextval('libs.dokprop_id_seq'::regclass);


--
-- TOC entry 3397 (class 2604 OID 40999)
-- Name: library id; Type: DEFAULT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.library ALTER COLUMN id SET DEFAULT nextval('libs.library_id_seq'::regclass);


--
-- TOC entry 3423 (class 2604 OID 106604)
-- Name: nomenklatuur id; Type: DEFAULT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.nomenklatuur ALTER COLUMN id SET DEFAULT nextval('libs.nomenklatuur_id_seq'::regclass);


--
-- TOC entry 3410 (class 2604 OID 90760)
-- Name: object id; Type: DEFAULT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.object ALTER COLUMN id SET DEFAULT nextval('libs.object_id_seq'::regclass);


--
-- TOC entry 3416 (class 2604 OID 98347)
-- Name: object_owner id; Type: DEFAULT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.object_owner ALTER COLUMN id SET DEFAULT nextval('libs.object_owner_id_seq'::regclass);


--
-- TOC entry 3436 (class 2604 OID 118039)
-- Name: aa id; Type: DEFAULT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.aa ALTER COLUMN id SET DEFAULT nextval('ou.aa_id_seq'::regclass);


--
-- TOC entry 3462 (class 2604 OID 122946)
-- Name: config id; Type: DEFAULT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.config ALTER COLUMN id SET DEFAULT nextval('ou.config_id_seq'::regclass);


--
-- TOC entry 3395 (class 2604 OID 32810)
-- Name: rekv id; Type: DEFAULT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.rekv ALTER COLUMN id SET DEFAULT nextval('ou.rekv_id_seq'::regclass);


--
-- TOC entry 3403 (class 2604 OID 49195)
-- Name: taotlus_login id; Type: DEFAULT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.taotlus_login ALTER COLUMN id SET DEFAULT nextval('ou.taotlus_login_id_seq'::regclass);


--
-- TOC entry 3392 (class 2604 OID 32795)
-- Name: userid id; Type: DEFAULT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.userid ALTER COLUMN id SET DEFAULT nextval('ou.userid_id_seq'::regclass);


--
-- TOC entry 3810 (class 0 OID 118050)
-- Dependencies: 255
-- Data for Name: arv; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.arv (id, rekvid, userid, journalid, doklausid, liik, operid, number, kpv, asutusid, arvid, lisa, tahtaeg, kbmta, kbm, summa, tasud, tasudok, muud, jaak, objektid, objekt, parentid, properties) FROM stdin;
6	1	4	0	1	0	0	2                   	2021-10-31	3	0	Arve, lepingu number 1 alusel 10/2021 kuu eest                                                                          	2021-11-15	10.0000	2.0000	12.0000	2021-10-26	\N	\N	0.0000	1	\N	34	{"aa": "EEXXXXXX", "viitenr": null}
\.


--
-- TOC entry 3812 (class 0 OID 122906)
-- Dependencies: 257
-- Data for Name: arv1; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.arv1 (id, parentid, nomid, kogus, hind, soodus, kbm, summa, muud, konto, kbmta, isikid, tunnus, proj, properties) FROM stdin;
1	6	1	10.000	1.0000	0	2.0000	12.0000			10.0000	0			\N
\.


--
-- TOC entry 3816 (class 0 OID 122963)
-- Dependencies: 261
-- Data for Name: arvtasu; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.arvtasu (id, rekvid, doc_arv_id, doc_tasu_id, kpv, summa, dok, pankkassa, muud, properties, status) FROM stdin;
3	1	34	41	2021-10-26	12.0000	\N	2	\N	\N	1
\.


--
-- TOC entry 3784 (class 0 OID 49204)
-- Dependencies: 224
-- Data for Name: doc; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.doc (id, rekvid, docs_ids, created, lastupdate, doc_type_id, bpm, history, status) FROM stdin;
10	\N	\N	2021-10-15 12:49:17.552214	2021-10-15 12:49:17.552214	8	\N	{"user": "Vladislav Gordin", "created": "2021-10-15T12:49:17.552214+03:00"}	0
11	\N	\N	2021-10-15 20:53:17.094253	2021-10-15 20:53:17.094253	8	\N	{"user": "Test 1", "created": "2021-10-15T20:53:17.094253+03:00"}	0
9	\N	\N	2021-10-15 12:44:59.906783	2021-10-15 12:44:59.906783	8	\N	{"user": "Vladislav Gordin", "created": "2021-10-15T12:44:59.906783+03:00"}	2
12	\N	\N	2021-10-15 21:04:42.303702	2021-10-15 21:04:42.303702	8	\N	{"user": "User 2", "created": "2021-10-15T21:04:42.303702+03:00"}	2
13	\N	\N	2021-10-15 21:07:59.087193	2021-10-15 21:07:59.087193	8	\N	{"user": "Jelena Golubeva", "created": "2021-10-15T21:07:59.087193+03:00"}	2
14	\N	\N	2021-10-15 21:12:00.23646	2021-10-15 21:12:00.23646	8	\N	{"user": "Vladislav Gordin", "created": "2021-10-15T21:12:00.23646+03:00"}	2
15	\N	\N	2021-10-15 21:14:24.077169	2021-10-15 21:14:24.077169	8	\N	{"user": "Lev Gordin", "created": "2021-10-15T21:14:24.077169+03:00"}	2
16	\N	\N	2021-10-15 21:29:29.971629	2021-10-15 21:29:29.971629	8	\N	{"user": "Jelena Golubeva", "created": "2021-10-15T21:29:29.971629+03:00"}	2
17	\N	\N	2021-10-18 13:55:36.864985	2021-10-18 13:55:36.864985	8	\N	{"user": "Isiku nimi", "created": "2021-10-18T13:55:36.864985+03:00"}	2
18	\N	\N	2021-10-18 23:59:28.766679	2021-10-18 23:59:28.766679	8	\N	{"user": "uus inimine", "created": "2021-10-18T23:59:28.766679+03:00"}	2
24	1	{34}	2021-10-20 23:30:38.035368	2021-10-20 23:41:45.767152	13	\N	[{"user": "isik", "created": "2021-10-20T23:30:38.035368+03:00"}, {"user": "isik", "updated": "2021-10-20T23:41:45.767152+03:00"}]	2
22	1	\N	2021-10-20 20:38:53.057297	2021-10-20 20:48:50.728454	11	\N	[{"user": "raama", "created": "2021-10-20T20:38:53.057297+03:00"}, {"user": "raama", "updated": "2021-10-20T20:43:36.814059+03:00"}, {"user": "raama", "updated": "2021-10-20T20:45:32.311308+03:00"}, {"user": "raama", "updated": "2021-10-20T20:48:50.728454+03:00"}]	1
23	1	\N	2021-10-20 20:57:15.336267	2021-10-20 20:57:15.336267	11	\N	[{"user": "raama", "created": "2021-10-20T20:57:15.336267+03:00"}]	1
43	1	\N	2021-10-26 20:42:13.662864	2021-10-27 20:20:45.143549	18	\N	[{"user": "juht", "created": "2021-10-26T20:42:13.662864+03:00"}, {"user": "juht", "updated": "2021-10-26T20:46:43.625881+03:00"}, {"user": "juht", "updated": "2021-10-26T22:02:31.383637+03:00"}, {"user": "juht", "updated": "2021-10-27T20:20:45.143549+03:00"}]	1
39	1	\N	2021-10-24 22:27:16.626599	2021-10-24 22:27:16.626599	15	\N	[{"user": "raama", "created": "2021-10-24T22:27:16.626599+03:00"}]	1
44	1	\N	2021-10-27 21:56:18.156357	2021-10-27 21:59:54.629528	18	\N	[{"user": "juht", "created": "2021-10-27T21:56:18.156357+03:00"}, {"user": "juht", "updated": "2021-10-27T21:59:54.629528+03:00"}]	1
38	1	\N	2021-10-24 20:43:34.519516	2021-10-26 09:03:51.441998	14	\N	[{"user": "raama", "created": "2021-10-24T20:43:34.519516+03:00"}, {"mk": {"id": 4, "kpv": "2021-10-24", "opt": 2, "aaid": 1, "jaak": 0.00, "muud": null, "selg": "Arve nr.2", "arvid": 34, "dokid": 0, "number": "3", "rekvid": 1, "doktyyp": 0, "viitenr": "", "parentid": 38, "doklausid": 0, "journalid": 0, "maksepaev": "2021-10-24", "properties": null}, "mk1": [[{"aa": "", "id": 4, "tp": null, "pank": null, "proj": "", "konto": null, "nomid": 3, "summa": 12.0000, "tunnus": "", "asutusid": 3, "parentid": 4, "journalid": null}]], "user": "Raamatupidaja                                                                                                                                                                                                                                                 ", "arvtasu": [[]], "deleted": "2021-10-26T09:03:51.441998+03:00"}]	3
41	1	{34}	2021-10-26 10:21:31.899425	2021-10-26 10:21:31.899425	16	\N	[{"user": "raama", "created": "2021-10-26T10:21:31.899425+03:00"}]	1
34	1	{24,41}	2021-10-23 17:38:49.256692	2021-10-23 17:38:49.256692	2	\N	[{"user": "raama", "created": "2021-10-23T17:38:49.256692+03:00"}]	2
\.


--
-- TOC entry 3823 (class 0 OID 172597)
-- Dependencies: 269
-- Data for Name: korder1; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.korder1 (id, parentid, rekvid, userid, journalid, kassaid, tyyp, doklausid, number, kpv, asutusid, nimi, aadress, dokument, alus, summa, muud, arvid, doktyyp, dokid) FROM stdin;
2	41	1	4	\N	2	1	\N	1	2021-10-26	3	Isiku nimi                                                                                                                                                                                                                                                    	Isiku aadress	\N	\N	12.0000	\N	34	\N	\N
\.


--
-- TOC entry 3825 (class 0 OID 172619)
-- Dependencies: 271
-- Data for Name: korder2; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.korder2 (id, parentid, nomid, nimetus, summa, konto, tunnus, proj, muud) FROM stdin;
1	2	4	Kassa sissemakse order	12.0000				\N
\.


--
-- TOC entry 3796 (class 0 OID 106535)
-- Dependencies: 237
-- Data for Name: leping1; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.leping1 (id, parentid, asutusid, objektid, rekvid, number, kpv, tahtaeg, selgitus, dok, muud, propertieds) FROM stdin;
3	22	3	1	1	1                   	2021-10-20	2025-12-29	\N	\N	\N	\N
4	23	4	2	1	1                   	2021-10-20	2031-10-20	\N	\N	\N	\N
\.


--
-- TOC entry 3802 (class 0 OID 114702)
-- Dependencies: 245
-- Data for Name: leping2; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.leping2 (id, parentid, nomid, kogus, hind, summa, status, muud, formula, kbm) FROM stdin;
1	3	1	1.000	1.0000	0.0000	1	\N	\N	0
2	4	1	0.000	1.0000	0.0000	1	\N	\N	0
\.


--
-- TOC entry 3819 (class 0 OID 172393)
-- Dependencies: 265
-- Data for Name: mk; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.mk (id, rekvid, journalid, aaid, doklausid, kpv, maksepaev, number, selg, viitenr, opt, muud, arvid, doktyyp, dokid, parentid, jaak, properties) FROM stdin;
5	1	0	1	0	2021-10-31	2021-10-31	4	Tagasimakse Arve nr.2		1	\N	0	0	0	39	12.00	\N
\.


--
-- TOC entry 3821 (class 0 OID 172424)
-- Dependencies: 267
-- Data for Name: mk1; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.mk1 (id, parentid, asutusid, nomid, summa, aa, pank, journalid, konto, tp, tunnus, proj) FROM stdin;
5	5	3	3	12.0000		\N	\N	\N	\N		
\.


--
-- TOC entry 3804 (class 0 OID 114741)
-- Dependencies: 248
-- Data for Name: moodu1; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.moodu1 (id, parentid, lepingid, kpv, muud, propertieds) FROM stdin;
1	24	22	2021-10-01	\N	\N
\.


--
-- TOC entry 3806 (class 0 OID 114758)
-- Dependencies: 250
-- Data for Name: moodu2; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.moodu2 (id, parentid, nomid, kogus, muud, properties) FROM stdin;
1	1	1	10.000	\N	\N
\.


--
-- TOC entry 3828 (class 0 OID 196758)
-- Dependencies: 278
-- Data for Name: rekl; Type: TABLE DATA; Schema: docs; Owner: postgres
--

COPY docs.rekl (id, rekvid, parentid, asutusid, alg_kpv, lopp_kpv, nimetus, link, muud, properties, "timestamp", status, ajalugu, last_shown) FROM stdin;
2	1	43	3	2021-10-26	2021-11-26	Reklaam	http://www.avpsoft.ee	\N	\N	2021-10-26 20:42:13.662864	1	\N	2021-10-27 22:21:52.286807
3	1	44	4	2021-10-27	2021-11-27	Reklaam 2	https://www.delfi.ee	\N	\N	2021-10-27 21:56:18.156357	1	\N	2021-10-27 22:21:52.286807
\.


--
-- TOC entry 3790 (class 0 OID 90784)
-- Dependencies: 230
-- Data for Name: asutus; Type: TABLE DATA; Schema: libs; Owner: postgres
--

COPY libs.asutus (id, rekvid, regkood, nimetus, omvorm, aadress, kontakt, tel, faks, email, muud, tp, staatus, mark, properties, ajalugi, kasutaja) FROM stdin;
3	1	\N	Isiku nimi                                                                                                                                                                                                                                                    	ISIK                	Isiku aadress	\N	tel                                                         	\N	email                                                       	\N	\N	1	\N	\N	\N	isik
4	1	\N	uus inimine                                                                                                                                                                                                                                                   	ISIK                	inimise aadress	\N	tema tel                                                    	\N	tema email                                                  	\N	\N	1	\N	\N	\N	men
\.


--
-- TOC entry 3792 (class 0 OID 98334)
-- Dependencies: 233
-- Data for Name: asutus_user_id; Type: TABLE DATA; Schema: libs; Owner: postgres
--

COPY libs.asutus_user_id (id, user_id, asutus_id, properties) FROM stdin;
1	14	3	\N
2	15	4	\N
\.


--
-- TOC entry 3798 (class 0 OID 106578)
-- Dependencies: 239
-- Data for Name: dokprop; Type: TABLE DATA; Schema: libs; Owner: postgres
--

COPY libs.dokprop (id, parentid, registr, vaatalaus, selg, muud, asutusid, details, proc_, tyyp, status, rekvid) FROM stdin;
\.


--
-- TOC entry 3780 (class 0 OID 40996)
-- Dependencies: 220
-- Data for Name: library; Type: TABLE DATA; Schema: libs; Owner: postgres
--

COPY libs.library (id, rekvid, kood, nimetus, library, muud, properties, "timestamp", status, ajalugu) FROM stdin;
1	1	TEATIS              	Teatised                                                                                                                                                                                                                                                      	DOK                 	\N	{"type": "library", "module": ["juht"]}	2021-10-14 16:38:05.940579	1	\N
6	1	USERID              	Kasutaja andmed                                                                                                                                                                                                                                               	DOK                 	\N	{"type": "settings", "module": ["admin"]}	2021-10-14 16:38:06.164106	1	\N
7	1	ARVED_KOODI_JARGI   	Arved koodi järgi                                                                                                                                                                                                                                             	DOK                 	\N	{"type": "aruanne", "module": ["raama"]}	2021-10-14 16:38:06.183963	1	\N
4	1	REKV                	Oma asutuse andmed                                                                                                                                                                                                                                            	DOK                 	\N	{"type": "settings", "module": ["admin", "raama", "juht"]}	2021-10-14 16:38:06.035666	1	\N
5	1	CONFIG              	Konfiguratsioon                                                                                                                                                                                                                                               	DOK                 	\N	{"type": "settings", "module": ["admin", "raama", "juht"]}	2021-10-14 16:38:06.121506	1	\N
8	1	TAOTLUS_LOGIN       	Registreerimise taotlused                                                                                                                                                                                                                                     	DOK                 	\N	{"type": "document", "module": ["admin"]}	2021-10-15 07:35:02.055099	1	\N
9	1	OBJEKT              	Objektid                                                                                                                                                                                                                                                      	DOK                 	\N	{"type": "library", "module": ["raama", "juht", "kasutaja"]}	2021-10-18 09:52:06.915577	1	\N
10	1	ASUTUSED            	Kliendid                                                                                                                                                                                                                                                      	DOK                 	\N	{"type": "library", "module": ["raama", "juht"]}	2021-10-18 10:13:15.189747	1	\N
11	1	LEPING              	Lepingud                                                                                                                                                                                                                                                      	DOK                 	\N	{"type": "document", "module": ["kasutaja", "raama", "juht"]}	2021-10-19 17:50:43.811366	1	\N
12	1	NOMENCLATURE        	Teenused                                                                                                                                                                                                                                                      	DOK                 	\N	{"type": "library", "module": ["raama", "juht"]}	2021-10-19 19:12:23.577134	1	\N
13	1	ANDMED              	Mõõdukiri andmed                                                                                                                                                                                                                                              	DOK                 	\N	{"type": "document", "module": ["kasutaja", "raama", "juht"]}	2021-10-20 18:55:31.12701	1	\N
2	1	ARV                 	Arved                                                                                                                                                                                                                                                         	DOK                 	\N	{"type": "document", "module": ["raama", "juht", "kasutaja"]}	2021-10-14 16:38:05.968084	1	\N
14	1	SMK                 	Sissemakse korraldused                                                                                                                                                                                                                                        	DOK                 	\N	{"type": "document", "module": ["raama"]}	2021-10-24 15:28:33.38833	1	\N
15	1	VMK                 	Väljamakse korraldused                                                                                                                                                                                                                                        	DOK                 	\N	{"type": "document", "module": ["raama"]}	2021-10-24 19:04:06.526218	1	\N
16	1	SORDER              	Sissemakse kassaorder                                                                                                                                                                                                                                         	DOK                 	\N	{"type": "document", "module": ["raama"]}	2021-10-24 19:33:51.068261	1	\N
17	1	VORDER              	Väljamakse kassaorder                                                                                                                                                                                                                                         	DOK                 	\N	{"type": "document", "module": ["raama"]}	2021-10-24 19:33:51.185674	1	\N
18	1	REKL                	Reklaam                                                                                                                                                                                                                                                       	DOK                 	\N	{"type": "document", "module": ["juht"]}	2021-10-26 16:11:58.239213	1	\N
19	1	KAIVE_ARUANNE       	Käibearuanne                                                                                                                                                                                                                                                  	DOK                 	\N	{"type": "aruanne", "module": ["raama"]}	2021-10-27 19:22:00.85798	1	\N
\.


--
-- TOC entry 3800 (class 0 OID 106601)
-- Dependencies: 241
-- Data for Name: nomenklatuur; Type: TABLE DATA; Schema: libs; Owner: postgres
--

COPY libs.nomenklatuur (id, rekvid, dok, kood, nimetus, uhik, hind, muud, kogus, formula, status, properties) FROM stdin;
1	1	ARV	vesi                	Vett kasutamine	m3	1.0000	\N	1.000	\N	0	{"vat": "20", "algoritm": "konstantne"}
3	1	SMK	SMK                 	Maksekorraldus	\N	0.0000	\N	0.000	\N	0	\N
4	1	SORDER	SORDER              	Kassa sissemakse order	\N	0.0000	\N	0.000	\N	0	\N
\.


--
-- TOC entry 3788 (class 0 OID 90757)
-- Dependencies: 228
-- Data for Name: object; Type: TABLE DATA; Schema: libs; Owner: postgres
--

COPY libs.object (id, rekvid, asutusid, aadress, muud, properties, "timestamp", status, ajalugu) FROM stdin;
2	1	4	inimise aadress	\N	\N	2021-10-18 23:59:56.847691	1	\N
1	1	3	Isiku aadress	\N	\N	2021-10-18 18:35:53.714776	1	\N
\.


--
-- TOC entry 3794 (class 0 OID 98344)
-- Dependencies: 235
-- Data for Name: object_owner; Type: TABLE DATA; Schema: libs; Owner: postgres
--

COPY libs.object_owner (id, object_id, asutus_id, properties) FROM stdin;
1	1	3	\N
2	2	4	\N
\.


--
-- TOC entry 3808 (class 0 OID 118036)
-- Dependencies: 253
-- Data for Name: aa; Type: TABLE DATA; Schema: ou; Owner: postgres
--

COPY ou.aa (id, parentid, arve, nimetus, saldo, default_, kassa, pank, konto, muud, tp) FROM stdin;
1	1	EEXXXXXX            	test arve                                                                                                                                                                                                                                                     	0.0000	1	1	767	100100              	\N	\N
2	1	KASSA               	Kassa                                                                                                                                                                                                                                                         	0.0000	1	0	0	\N	\N	\N
\.


--
-- TOC entry 3814 (class 0 OID 122943)
-- Dependencies: 259
-- Data for Name: config; Type: TABLE DATA; Schema: ou; Owner: postgres
--

COPY ou.config (id, rekvid, keel, toolbar1, toolbar2, toolbar3, number, arvround, asutusid, tahtpaev, www1, dokprop1, dokprop2, propertis) FROM stdin;
1	1	2	0	0	0		0.10	0	0		0	0	\N
\.


--
-- TOC entry 3777 (class 0 OID 32807)
-- Dependencies: 215
-- Data for Name: rekv; Type: TABLE DATA; Schema: ou; Owner: postgres
--

COPY ou.rekv (id, parentid, regkood, nimetus, kbmkood, aadress, haldus, tel, faks, email, juht, raama, muud, properties, ajalugu, status) FROM stdin;
1	0	123456789           	Korteriühistu	                    	Narva					Juht	Raama	\N	\N	\N	1
\.


--
-- TOC entry 3782 (class 0 OID 49192)
-- Dependencies: 222
-- Data for Name: taotlus_login; Type: TABLE DATA; Schema: ou; Owner: postgres
--

COPY ou.taotlus_login (id, parentid, kpv, kasutaja, parool, nimi, aadress, email, tel, muud, properties, ajalugu, status) FROM stdin;
9	10	2021-10-15	temp	\N	Vladislav Gordin                                                                                                                                                                                                                                              	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "Vladislav Gordin", "created": "2021-10-15T12:49:17.552214+03:00"}	2
10	11	2021-10-15	test 1	\N	Test 1                                                                                                                                                                                                                                                        	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "Test 1", "created": "2021-10-15T20:53:17.094253+03:00"}	2
8	9	2021-10-15	temp	\N	Vladislav Gordin                                                                                                                                                                                                                                              	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "Vladislav Gordin", "created": "2021-10-15T12:44:59.906783+03:00"}	2
11	12	2021-10-15	user 2	\N	User 2                                                                                                                                                                                                                                                        	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "User 2", "created": "2021-10-15T21:04:42.303702+03:00"}	2
12	13	2021-10-15	temp	\N	Jelena Golubeva                                                                                                                                                                                                                                               	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "Jelena Golubeva", "created": "2021-10-15T21:07:59.087193+03:00"}	2
13	14	2021-10-15	temp 2	\N	Vladislav Gordin                                                                                                                                                                                                                                              	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "Vladislav Gordin", "created": "2021-10-15T21:12:00.23646+03:00"}	2
14	15	2021-10-15	temp 3	\N	Lev Gordin                                                                                                                                                                                                                                                    	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "Lev Gordin", "created": "2021-10-15T21:14:24.077169+03:00"}	2
15	16	2021-10-15	temp 5	\N	Jelena Golubeva                                                                                                                                                                                                                                               	Aadress	vladislav.gordin@gmail.com	53480604	\N	\N	{"user": "Jelena Golubeva", "created": "2021-10-15T21:29:29.971629+03:00"}	2
16	17	2021-10-18	isik	\N	Isiku nimi                                                                                                                                                                                                                                                    	Isiku aadress	email	tel	\N	\N	{"user": "Isiku nimi", "created": "2021-10-18T13:55:36.864985+03:00"}	2
17	18	2021-10-18	men	\N	uus inimine                                                                                                                                                                                                                                                   	inimise aadress	tema email	tema tel	\N	\N	{"user": "uus inimine", "created": "2021-10-18T23:59:28.766679+03:00"}	2
\.


--
-- TOC entry 3775 (class 0 OID 32792)
-- Dependencies: 213
-- Data for Name: userid; Type: TABLE DATA; Schema: ou; Owner: postgres
--

COPY ou.userid (id, rekvid, kasutaja, ametnik, parool, muud, last_login, properties, roles, ajalugu, status) FROM stdin;
14	1	isik                                              	Isiku nimi                                                                                                                                                                                                                                                    		\N	2021-10-27 21:56:30.292056	\N	{"is_kasutaja": true}	\N	0
3	1	kasutaja                                          	Korteri omanik                                                                                                                                                                                                                                                	\N	\N	2021-10-21 00:20:17.493352	\N	{"is_kasutaja": true}	\N	0
8	1	user 2                                            	User 2                                                                                                                                                                                                                                                        		\N	2021-10-15 21:07:14.567262	\N	{"is_kasutaja": true}	\N	0
6	1	temp                                              	Vladislav Gordin                                                                                                                                                                                                                                              		\N	2021-10-16 20:18:14.920338	\N	{"is_kasutaja": true}	\N	0
9	1	temp 2                                            	Vladislav Gordin                                                                                                                                                                                                                                              		\N	2021-10-15 21:12:23.811412	\N	{"is_kasutaja": true}	\N	0
7	1	test 1                                            	Test 1                                                                                                                                                                                                                                                        		\N	2021-10-15 20:53:53.668974	\N	{"is_kasutaja": true}	\N	0
10	1	temp 3                                            	Lev Gordin                                                                                                                                                                                                                                                    		\N	2021-10-15 21:15:09.809829	\N	{"is_kasutaja": true}	\N	0
11	1	temp 5                                            	Jelena Golubeva                                                                                                                                                                                                                                               		\N	2021-10-18 09:43:11.705267	\N	{"is_kasutaja": true}	\N	0
1	1	admin                                             	Administratoor                                                                                                                                                                                                                                                	\N	\N	2021-10-27 21:27:35.65399	{"is_admin": true}	{"is_admin": true}	\N	0
2	1	juht                                              	Juhataja                                                                                                                                                                                                                                                      	\N	\N	2021-10-27 21:42:52.058956	\N	{"is_juht": true}	\N	0
15	1	men                                               	uus inimine                                                                                                                                                                                                                                                   		\N	2021-10-19 00:33:00.234094	\N	{"is_kasutaja": true}	\N	0
4	1	raama                                             	Raamatupidaja                                                                                                                                                                                                                                                 	\N	\N	2021-10-27 22:52:36.072378	\N	{"is_raama": true}	\N	0
\.


--
-- TOC entry 3778 (class 0 OID 32828)
-- Dependencies: 217
-- Data for Name: session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session (sid, sess, expire) FROM stdin;
viaC3p71_7FNqyWCCAYkSiDEoFNoSTEp	{"cookie":{"originalMaxAge":86399994,"expires":"2021-10-28T20:07:39.083Z","httpOnly":true,"path":"/"},"users":[{"uuid":"4c286380-3741-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:44:26.071Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:44:26.071Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"],"userAllowedAsutused":["{\\"id\\":1,\\"regkood\\":\\"123456789           \\",\\"nimetus\\":\\"Korteriühistu\\",\\"parentid\\":0,\\"user_id\\":14}"]},{"uuid":"05fbccc0-3742-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T16:16:53.236Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T16:16:53.236Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"53b78cb0-3742-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T16:22:05.007Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T16:22:05.007Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"b24183d0-3742-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T16:24:15.409Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T16:24:15.409Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"ffc4f5b0-3742-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T16:26:54.018Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T16:26:54.018Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"51f4b190-3743-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T16:29:04.078Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T16:29:04.078Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"8f021e60-3743-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T16:31:21.947Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T16:31:21.947Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"5bc721c0-3749-11ec-92a1-032bd7e38811","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T19:57:12.622Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T19:57:12.622Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"],"userAllowedAsutused":["{\\"id\\":1,\\"regkood\\":\\"123456789           \\",\\"nimetus\\":\\"Korteriühistu\\",\\"parentid\\":0,\\"user_id\\":2}"]},{"uuid":"846bf290-3749-11ec-92a1-032bd7e38811","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-27T17:14:35.407Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-27T17:14:35.407Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"0c68b8e0-374a-11ec-92a1-032bd7e38811","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-27T17:15:43.601Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-27T17:15:43.601Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"00893670-374b-11ec-92a1-032bd7e38811","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-27T17:19:31.747Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-27T17:19:31.747Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"cfbe3a50-374e-11ec-92a1-032bd7e38811","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-27T17:26:21.321Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-27T17:26:21.321Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"fcab3c20-374e-11ec-92a1-032bd7e38811","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-27T17:53:37.452Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-27T17:53:37.452Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"18edbb60-374f-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T16:33:04.516Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T16:33:04.516Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"6f116dc0-374f-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T17:55:40.230Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T17:55:40.230Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"6bfe9300-3750-11ec-92a1-032bd7e38811","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T17:58:04.753Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T17:58:04.753Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"3ece5130-3751-11ec-92a1-032bd7e38811","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-27T17:54:52.963Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-27T17:54:52.963Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"df487870-3751-11ec-92a1-032bd7e38811","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-18T20:59:38.709Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-18T20:59:38.709Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"],"userAllowedAsutused":["{\\"id\\":1,\\"regkood\\":\\"123456789           \\",\\"nimetus\\":\\"Korteriühistu\\",\\"parentid\\":0,\\"user_id\\":1}"]},{"uuid":"04db0030-3752-11ec-9542-75e85be9c463","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-27T18:15:32.010Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-27T18:15:32.010Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"300d59b0-3752-11ec-9542-75e85be9c463","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-27T18:16:35.059Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-27T18:16:35.059Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"615d8e90-3752-11ec-a66a-69b6dedf462a","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-27T18:17:47.517Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-27T18:17:47.517Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"a3627f30-3752-11ec-9936-d9656609c3bf","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-27T18:19:10.264Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-27T18:19:10.264Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"c9ebc300-3752-11ec-9936-d9656609c3bf","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-27T18:21:01.028Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-27T18:21:01.028Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"13d4d010-3753-11ec-a155-913cb968fe74","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-27T18:22:05.667Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-27T18:22:05.667Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"8e9a68a0-3753-11ec-9985-5f28bd375f7f","userId":1,"userName":"Administratoor","asutusId":1,"lastLogin":"2021-10-27T18:24:09.671Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"admin","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_admin":true},"id":1,"rekvid":1,"kasutaja":"admin","ametnik":"Administratoor","parool":null,"muud":null,"last_login":"2021-10-27T18:24:09.671Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"449db710-3754-11ec-9985-5f28bd375f7f","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T18:05:09.092Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T18:05:09.092Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"762576b0-3754-11ec-9985-5f28bd375f7f","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T18:32:41.012Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T18:32:41.012Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"b0d43d90-3755-11ec-9985-5f28bd375f7f","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-27T18:11:02.774Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-27T18:11:02.774Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"9887ecd0-3757-11ec-9985-5f28bd375f7f","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-27T18:34:04.110Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-27T18:34:04.110Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"f3bee100-375a-11ec-99fb-751ba46b88d6","userId":4,"userName":"Raamatupidaja","asutusId":1,"lastLogin":"2021-10-26T08:07:19.527Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"raama","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_raama":true},"id":4,"rekvid":1,"kasutaja":"raama","ametnik":"Raamatupidaja","parool":null,"muud":null,"last_login":"2021-10-26T08:07:19.527Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"],"userAllowedAsutused":["{\\"id\\":1,\\"regkood\\":\\"123456789           \\",\\"nimetus\\":\\"Korteriühistu\\",\\"parentid\\":0,\\"user_id\\":4}"]},{"uuid":"2d47baf0-375b-11ec-99fb-751ba46b88d6","userId":4,"userName":"Raamatupidaja","asutusId":1,"lastLogin":"2021-10-27T19:20:31.811Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"raama","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_raama":true},"id":4,"rekvid":1,"kasutaja":"raama","ametnik":"Raamatupidaja","parool":null,"muud":null,"last_login":"2021-10-27T19:20:31.811Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}","{\\"id\\":19,\\"nimetus\\":\\"Käibearuanne\\"}"]},{"uuid":"ae4677b0-375e-11ec-99fb-751ba46b88d6","userId":4,"userName":"Raamatupidaja","asutusId":1,"lastLogin":"2021-10-27T19:22:08.341Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"raama","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_raama":true},"id":4,"rekvid":1,"kasutaja":"raama","ametnik":"Raamatupidaja","parool":null,"muud":null,"last_login":"2021-10-27T19:22:08.341Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}","{\\"id\\":19,\\"nimetus\\":\\"Käibearuanne\\"}"]},{"uuid":"d592bd60-375e-11ec-ba8e-2bd0ce9ebebe","userId":4,"userName":"Raamatupidaja","asutusId":1,"lastLogin":"2021-10-27T19:47:13.247Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"raama","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_raama":true},"id":4,"rekvid":1,"kasutaja":"raama","ametnik":"Raamatupidaja","parool":null,"muud":null,"last_login":"2021-10-27T19:47:13.247Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}","{\\"id\\":19,\\"nimetus\\":\\"Käibearuanne\\"}"]},{"uuid":"eccb1b30-375e-11ec-a5e0-df5161ee457a","userId":4,"userName":"Raamatupidaja","asutusId":1,"lastLogin":"2021-10-27T19:48:19.196Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"raama","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_raama":true},"id":4,"rekvid":1,"kasutaja":"raama","ametnik":"Raamatupidaja","parool":null,"muud":null,"last_login":"2021-10-27T19:48:19.196Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}","{\\"id\\":19,\\"nimetus\\":\\"Käibearuanne\\"}"]},{"uuid":"6eb06ec0-375f-11ec-a743-bdf913690dea","userId":4,"userName":"Raamatupidaja","asutusId":1,"lastLogin":"2021-10-27T19:48:58.136Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"raama","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_raama":true},"id":4,"rekvid":1,"kasutaja":"raama","ametnik":"Raamatupidaja","parool":null,"muud":null,"last_login":"2021-10-27T19:48:58.136Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}","{\\"id\\":19,\\"nimetus\\":\\"Käibearuanne\\"}"]}]}	2021-10-28 23:07:40
6SFt63qYumz7eqhs3l9yWXFHMBsocCpv	{"cookie":{"originalMaxAge":86399993,"expires":"2021-10-27T21:53:35.645Z","httpOnly":true,"path":"/"},"users":[{"uuid":"d095b3d0-3678-11ec-934a-fb8481683d43","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-24T15:10:31.593Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-24T15:10:31.593Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"],"userAllowedAsutused":["{\\"id\\":1,\\"regkood\\":\\"123456789           \\",\\"nimetus\\":\\"Korteriühistu\\",\\"parentid\\":0,\\"user_id\\":2}"]},{"uuid":"09a27ff0-3679-11ec-934a-fb8481683d43","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:21:46.576Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:21:46.576Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"3b920210-3679-11ec-934a-fb8481683d43","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:23:22.277Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:23:22.277Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"601cb6c0-3679-11ec-934a-fb8481683d43","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:24:46.055Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:24:46.055Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"a49ae4c0-3679-11ec-934a-fb8481683d43","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:25:47.359Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:25:47.359Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"b5157db0-3679-11ec-8f50-49f032465641","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:27:42.286Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:27:42.286Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"c9259970-3679-11ec-8f50-49f032465641","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:28:09.921Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:28:09.921Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"57c0b5c0-367a-11ec-8f50-49f032465641","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:28:43.583Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:28:43.583Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"94e118e0-367b-11ec-840f-03cbff056666","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:32:42.831Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:32:42.831Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"5ab13a70-3684-11ec-8fd7-217b43b0a431","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T16:41:34.887Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T16:41:34.887Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"81b8fd10-3684-11ec-8fd7-217b43b0a431","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T17:44:22.747Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T17:44:22.747Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"fbc78530-3685-11ec-8fd7-217b43b0a431","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T08:14:00.829Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T08:14:00.829Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"],"userAllowedAsutused":["{\\"id\\":1,\\"regkood\\":\\"123456789           \\",\\"nimetus\\":\\"Korteriühistu\\",\\"parentid\\":0,\\"user_id\\":14}"]},{"uuid":"1f8d1520-3686-11ec-8fd7-217b43b0a431","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T17:56:02.487Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T17:56:02.487Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"769d9880-3686-11ec-8fd7-217b43b0a431","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T17:57:02.500Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T17:57:02.500Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"c180e410-3686-11ec-8fd7-217b43b0a431","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T17:59:28.570Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T17:59:28.570Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"f1e2e860-3686-11ec-8fd7-217b43b0a431","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:01:34.211Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:01:34.211Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"23ea8660-3687-11ec-8fd7-217b43b0a431","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:02:55.525Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:02:55.525Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"65c336e0-3687-11ec-b243-db6968eba246","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:04:19.323Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:04:19.323Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"9ac83660-3687-11ec-b243-db6968eba246","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:06:09.797Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:06:09.797Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"9b17b5f0-3687-11ec-b243-db6968eba246","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:07:38.749Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:07:38.749Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"a7300630-3687-11ec-b243-db6968eba246","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:07:39.268Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:07:39.268Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"1db2c4f0-3688-11ec-b243-db6968eba246","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:07:59.561Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:07:59.561Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"31ad5ce0-3688-11ec-967d-17775f65c372","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:11:18.387Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:11:18.387Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"ab4e4b90-3688-11ec-967d-17775f65c372","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:11:51.917Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:11:51.917Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"c8a7e020-3688-11ec-b104-95fb89cecc53","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:15:15.963Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:15:15.963Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"91d317c0-368a-11ec-b104-95fb89cecc53","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:16:05.219Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:16:05.219Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"c81f6450-368a-11ec-b104-95fb89cecc53","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:28:52.208Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:28:52.208Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"0b8173f0-368b-11ec-b104-95fb89cecc53","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:30:23.304Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:30:23.304Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"72a43180-368b-11ec-80b2-31906a736072","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:32:16.352Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:32:16.352Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"9a0ab5f0-368b-11ec-a084-4db2911c054f","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:35:09.555Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:35:09.555Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"e9d75480-368b-11ec-a084-4db2911c054f","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:36:15.501Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:36:15.501Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"31751200-368c-11ec-9de7-e311c2d5d011","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:38:29.371Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:38:29.371Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"85f8a8f0-368c-11ec-9de7-e311c2d5d011","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:40:29.525Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:40:29.525Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"f7889ed0-368c-11ec-aed7-adfa448ed867","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:42:51.317Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:42:51.317Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"4bd40ec0-368d-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:46:01.982Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:46:01.982Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"9306ae60-368d-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:48:23.283Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:48:23.283Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"ce5ad270-368d-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:50:22.712Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:50:22.712Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"1024b5e0-368e-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:52:02.389Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:52:02.389Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"29296f40-368e-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:53:52.626Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:53:52.626Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"990ee970-368e-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:54:34.597Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:54:34.597Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"a93b3b50-368e-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:57:42.330Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:57:42.330Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"1ed017a0-368f-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T18:58:09.465Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T18:58:09.465Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"32f91290-368f-11ec-97bd-e53edabb11b2","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T17:45:28.222Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T17:45:28.222Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"aa7f3790-368f-11ec-97bd-e53edabb11b2","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:01:26.737Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:01:26.737Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"c5ad27a0-3691-11ec-9ab6-31214dbb04f3","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:05:21.237Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:05:21.237Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"177b4610-3693-11ec-9ab6-31214dbb04f3","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:20:25.787Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:20:25.787Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"54c88590-3694-11ec-8629-d38828b5dbbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:29:52.425Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:29:52.425Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"30069ed0-3695-11ec-98e5-195b45419665","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:38:44.768Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:38:44.768Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"a30bf6a0-3695-11ec-98e5-195b45419665","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:44:52.592Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:44:52.592Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"e6d309a0-3695-11ec-b093-6d7e386b8775","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:48:05.572Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:48:05.572Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"8ab0a730-3696-11ec-b093-6d7e386b8775","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:49:59.277Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:49:59.277Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"e91d0430-3696-11ec-a2c3-33a9cb3fd3f9","userId":2,"userName":"Juhataja","asutusId":1,"lastLogin":"2021-10-26T19:02:00.710Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"juht","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_juht":true},"id":2,"rekvid":1,"kasutaja":"juht","ametnik":"Juhataja","parool":null,"muud":null,"last_login":"2021-10-26T19:02:00.710Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"0aa09360-3697-11ec-a2c3-33a9cb3fd3f9","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:54:34.224Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:54:34.224Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"710ebc10-3699-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T19:58:08.838Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T19:58:08.838Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"0b619210-369a-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:15:19.710Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:15:19.710Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"588cf8e0-369a-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:19:38.732Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:19:38.732Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"d4265c30-369a-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:21:48.066Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:21:48.066Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"a455a5f0-369b-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:25:15.431Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:25:15.431Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"6c99ce60-369c-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:31:04.707Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:31:04.707Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"d8211e90-369c-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:36:40.766Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:36:40.766Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"6d2a5920-369d-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:39:41.163Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:39:41.163Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"8a7c7e30-369e-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:43:51.245Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:43:51.245Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"f39e6720-369e-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:51:49.829Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:51:49.829Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"d1158070-369f-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T20:54:46.211Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T20:54:46.211Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"0d17bed0-36a0-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:00:57.769Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:00:57.769Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"beba9950-36a0-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:02:38.457Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:02:38.457Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"450e1c70-36a1-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:07:36.473Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:07:36.473Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"cbc7b460-36a1-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:11:21.834Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:11:21.834Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"822ad610-36a2-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:15:07.865Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:15:07.865Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"efd81380-36a2-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:20:13.860Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:20:13.860Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"156718d0-36a3-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:23:17.868Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:23:17.868Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"3c826370-36a3-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:24:20.883Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:24:20.883Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"8f569cb0-36a3-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:25:26.493Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:25:26.493Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"cffa9dc0-36a3-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:27:45.452Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:27:45.452Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"a62885a0-36a5-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:29:33.903Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:29:33.903Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]},{"uuid":"e3c0f460-36a5-11ec-b7e5-e7c994d88cbe","userId":14,"userName":"Isiku nimi","asutusId":1,"lastLogin":"2021-10-26T21:42:42.730Z","userAccessList":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"login":"isik","parentid":0,"parent_asutus":"Korteriühistu","roles":{"is_kasutaja":true},"id":14,"rekvid":1,"kasutaja":"isik","ametnik":"Isiku nimi","parool":"","muud":null,"last_login":"2021-10-26T21:42:42.730Z","asutus":"Korteriühistu","asutus_tais":"Korteriühistu","regkood":"123456789","aadress":"Narva","tel":"","email":"","allowed_access":["{\\"id\\":1,\\"nimetus\\":\\"Korteriühistu\\"}"],"allowed_libs":["{\\"id\\":4,\\"nimetus\\":\\"Oma asutuse andmed\\"}","{\\"id\\":5,\\"nimetus\\":\\"Konfiguratsioon\\"}","{\\"id\\":6,\\"nimetus\\":\\"Kasutaja andmed\\"}","{\\"id\\":8,\\"nimetus\\":\\"Registreerimise taotlused\\"}","{\\"id\\":1,\\"nimetus\\":\\"Teatised\\"}","{\\"id\\":18,\\"nimetus\\":\\"Reklaam\\"}","{\\"id\\":11,\\"nimetus\\":\\"Lepingud\\"}","{\\"id\\":13,\\"nimetus\\":\\"Mõõdukiri andmed\\"}","{\\"id\\":9,\\"nimetus\\":\\"Objektid\\"}","{\\"id\\":2,\\"nimetus\\":\\"Arved\\"}","{\\"id\\":10,\\"nimetus\\":\\"Kliendid\\"}","{\\"id\\":12,\\"nimetus\\":\\"Teenused\\"}","{\\"id\\":7,\\"nimetus\\":\\"Arved koodi järgi\\"}","{\\"id\\":14,\\"nimetus\\":\\"Sissemakse korraldused\\"}","{\\"id\\":15,\\"nimetus\\":\\"Väljamakse korraldused\\"}","{\\"id\\":16,\\"nimetus\\":\\"Sissemakse kassaorder\\"}","{\\"id\\":17,\\"nimetus\\":\\"Väljamakse kassaorder\\"}"]}]}	2021-10-28 00:53:36
\.


--
-- TOC entry 3786 (class 0 OID 65939)
-- Dependencies: 226
-- Data for Name: v_taotlus; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.v_taotlus (id, parentid, kpv, kasutaja, parool, nimi, aadress, email, tel, muud, properties, ajalugu, status) FROM stdin;
\.


--
-- TOC entry 3785 (class 0 OID 65932)
-- Dependencies: 225
-- Data for Name: v_user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.v_user (id, rekvid, kasutaja, ametnik, parool, muud, last_login, properties, roles, ajalugu, status) FROM stdin;
1	1	admin                                             	Administratoor                                                                                                                                                                                                                                                	\N	\N	2021-10-15 20:40:44.435347	\N	{"is_admin": true}	\N	0
\.


--
-- TOC entry 3965 (class 0 OID 0)
-- Dependencies: 256
-- Name: arv1_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.arv1_id_seq', 1, true);


--
-- TOC entry 3966 (class 0 OID 0)
-- Dependencies: 254
-- Name: arv_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.arv_id_seq', 6, true);


--
-- TOC entry 3967 (class 0 OID 0)
-- Dependencies: 260
-- Name: arvtasu_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.arvtasu_id_seq', 3, true);


--
-- TOC entry 3968 (class 0 OID 0)
-- Dependencies: 223
-- Name: doc_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.doc_id_seq', 44, true);


--
-- TOC entry 3969 (class 0 OID 0)
-- Dependencies: 268
-- Name: korder1_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.korder1_id_seq', 2, true);


--
-- TOC entry 3970 (class 0 OID 0)
-- Dependencies: 270
-- Name: korder2_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.korder2_id_seq', 1, true);


--
-- TOC entry 3971 (class 0 OID 0)
-- Dependencies: 236
-- Name: leping1_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.leping1_id_seq', 4, true);


--
-- TOC entry 3972 (class 0 OID 0)
-- Dependencies: 244
-- Name: leping2_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.leping2_id_seq', 2, true);


--
-- TOC entry 3973 (class 0 OID 0)
-- Dependencies: 266
-- Name: mk1_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.mk1_id_seq', 5, true);


--
-- TOC entry 3974 (class 0 OID 0)
-- Dependencies: 264
-- Name: mk_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.mk_id_seq', 5, true);


--
-- TOC entry 3975 (class 0 OID 0)
-- Dependencies: 247
-- Name: moodu1_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.moodu1_id_seq', 1, true);


--
-- TOC entry 3976 (class 0 OID 0)
-- Dependencies: 249
-- Name: moodu2_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.moodu2_id_seq', 1, true);


--
-- TOC entry 3977 (class 0 OID 0)
-- Dependencies: 277
-- Name: rekl_id_seq; Type: SEQUENCE SET; Schema: docs; Owner: postgres
--

SELECT pg_catalog.setval('docs.rekl_id_seq', 3, true);


--
-- TOC entry 3978 (class 0 OID 0)
-- Dependencies: 229
-- Name: asutus_id_seq; Type: SEQUENCE SET; Schema: libs; Owner: postgres
--

SELECT pg_catalog.setval('libs.asutus_id_seq', 4, true);


--
-- TOC entry 3979 (class 0 OID 0)
-- Dependencies: 232
-- Name: asutus_user_id_id_seq; Type: SEQUENCE SET; Schema: libs; Owner: postgres
--

SELECT pg_catalog.setval('libs.asutus_user_id_id_seq', 2, true);


--
-- TOC entry 3980 (class 0 OID 0)
-- Dependencies: 238
-- Name: dokprop_id_seq; Type: SEQUENCE SET; Schema: libs; Owner: postgres
--

SELECT pg_catalog.setval('libs.dokprop_id_seq', 1, false);


--
-- TOC entry 3981 (class 0 OID 0)
-- Dependencies: 219
-- Name: library_id_seq; Type: SEQUENCE SET; Schema: libs; Owner: postgres
--

SELECT pg_catalog.setval('libs.library_id_seq', 19, true);


--
-- TOC entry 3982 (class 0 OID 0)
-- Dependencies: 240
-- Name: nomenklatuur_id_seq; Type: SEQUENCE SET; Schema: libs; Owner: postgres
--

SELECT pg_catalog.setval('libs.nomenklatuur_id_seq', 4, true);


--
-- TOC entry 3983 (class 0 OID 0)
-- Dependencies: 227
-- Name: object_id_seq; Type: SEQUENCE SET; Schema: libs; Owner: postgres
--

SELECT pg_catalog.setval('libs.object_id_seq', 2, true);


--
-- TOC entry 3984 (class 0 OID 0)
-- Dependencies: 234
-- Name: object_owner_id_seq; Type: SEQUENCE SET; Schema: libs; Owner: postgres
--

SELECT pg_catalog.setval('libs.object_owner_id_seq', 2, true);


--
-- TOC entry 3985 (class 0 OID 0)
-- Dependencies: 252
-- Name: aa_id_seq; Type: SEQUENCE SET; Schema: ou; Owner: postgres
--

SELECT pg_catalog.setval('ou.aa_id_seq', 2, true);


--
-- TOC entry 3986 (class 0 OID 0)
-- Dependencies: 258
-- Name: config_id_seq; Type: SEQUENCE SET; Schema: ou; Owner: postgres
--

SELECT pg_catalog.setval('ou.config_id_seq', 1, true);


--
-- TOC entry 3987 (class 0 OID 0)
-- Dependencies: 214
-- Name: rekv_id_seq; Type: SEQUENCE SET; Schema: ou; Owner: postgres
--

SELECT pg_catalog.setval('ou.rekv_id_seq', 1, true);


--
-- TOC entry 3988 (class 0 OID 0)
-- Dependencies: 221
-- Name: taotlus_login_id_seq; Type: SEQUENCE SET; Schema: ou; Owner: postgres
--

SELECT pg_catalog.setval('ou.taotlus_login_id_seq', 17, true);


--
-- TOC entry 3989 (class 0 OID 0)
-- Dependencies: 212
-- Name: userid_id_seq; Type: SEQUENCE SET; Schema: ou; Owner: postgres
--

SELECT pg_catalog.setval('ou.userid_id_seq', 15, true);


--
-- TOC entry 3990 (class 0 OID 0)
-- Dependencies: 262
-- Name: arv_1_number; Type: SEQUENCE SET; Schema: public; Owner: db
--

SELECT pg_catalog.setval('public.arv_1_number', 1, true);


--
-- TOC entry 3991 (class 0 OID 0)
-- Dependencies: 273
-- Name: smk_1_number; Type: SEQUENCE SET; Schema: public; Owner: db
--

SELECT pg_catalog.setval('public.smk_1_number', 3, true);


--
-- TOC entry 3577 (class 2606 OID 122920)
-- Name: arv1 arv1_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.arv1
    ADD CONSTRAINT arv1_pkey PRIMARY KEY (id);


--
-- TOC entry 3569 (class 2606 OID 118069)
-- Name: arv arv_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.arv
    ADD CONSTRAINT arv_pkey PRIMARY KEY (id);


--
-- TOC entry 3584 (class 2606 OID 122974)
-- Name: arvtasu arvtasu_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.arvtasu
    ADD CONSTRAINT arvtasu_pkey PRIMARY KEY (id);


--
-- TOC entry 3522 (class 2606 OID 49214)
-- Name: doc docs_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.doc
    ADD CONSTRAINT docs_pkey PRIMARY KEY (id);


--
-- TOC entry 3602 (class 2606 OID 172607)
-- Name: korder1 korder1_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.korder1
    ADD CONSTRAINT korder1_pkey PRIMARY KEY (id);


--
-- TOC entry 3607 (class 2606 OID 172627)
-- Name: korder2 korder2_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.korder2
    ADD CONSTRAINT korder2_pkey PRIMARY KEY (id);


--
-- TOC entry 3545 (class 2606 OID 106542)
-- Name: leping1 leping1_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.leping1
    ADD CONSTRAINT leping1_pkey PRIMARY KEY (id);


--
-- TOC entry 3556 (class 2606 OID 114714)
-- Name: leping2 leping2_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.leping2
    ADD CONSTRAINT leping2_pkey PRIMARY KEY (id);


--
-- TOC entry 3596 (class 2606 OID 172430)
-- Name: mk1 mk1_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.mk1
    ADD CONSTRAINT mk1_pkey PRIMARY KEY (id);


--
-- TOC entry 3590 (class 2606 OID 172413)
-- Name: mk mk_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.mk
    ADD CONSTRAINT mk_pkey PRIMARY KEY (id);


--
-- TOC entry 3560 (class 2606 OID 114748)
-- Name: moodu1 moodu1_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.moodu1
    ADD CONSTRAINT moodu1_pkey PRIMARY KEY (id);


--
-- TOC entry 3564 (class 2606 OID 114766)
-- Name: moodu2 moodu2_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.moodu2
    ADD CONSTRAINT moodu2_pkey PRIMARY KEY (id);


--
-- TOC entry 3610 (class 2606 OID 196767)
-- Name: rekl rekl_pkey; Type: CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.rekl
    ADD CONSTRAINT rekl_pkey PRIMARY KEY (id);


--
-- TOC entry 3532 (class 2606 OID 90792)
-- Name: asutus asutus_pkey; Type: CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.asutus
    ADD CONSTRAINT asutus_pkey PRIMARY KEY (id);


--
-- TOC entry 3537 (class 2606 OID 98341)
-- Name: asutus_user_id asutus_user_id_pkey; Type: CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.asutus_user_id
    ADD CONSTRAINT asutus_user_id_pkey PRIMARY KEY (id);


--
-- TOC entry 3549 (class 2606 OID 106589)
-- Name: dokprop dokprop_pkey; Type: CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.dokprop
    ADD CONSTRAINT dokprop_pkey PRIMARY KEY (id);


--
-- TOC entry 3517 (class 2606 OID 41008)
-- Name: library library_pkey; Type: CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.library
    ADD CONSTRAINT library_pkey PRIMARY KEY (id);


--
-- TOC entry 3551 (class 2606 OID 106611)
-- Name: nomenklatuur nomenklatuur_pkey; Type: CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.nomenklatuur
    ADD CONSTRAINT nomenklatuur_pkey PRIMARY KEY (id);


--
-- TOC entry 3540 (class 2606 OID 98351)
-- Name: object_owner object_owner_pkey; Type: CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.object_owner
    ADD CONSTRAINT object_owner_pkey PRIMARY KEY (id);


--
-- TOC entry 3527 (class 2606 OID 90766)
-- Name: object object_pkey; Type: CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.object
    ADD CONSTRAINT object_pkey PRIMARY KEY (id);


--
-- TOC entry 3567 (class 2606 OID 118047)
-- Name: aa aa_pkey; Type: CONSTRAINT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.aa
    ADD CONSTRAINT aa_pkey PRIMARY KEY (id);


--
-- TOC entry 3579 (class 2606 OID 122961)
-- Name: config config__pkey; Type: CONSTRAINT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.config
    ADD CONSTRAINT config__pkey PRIMARY KEY (id);


--
-- TOC entry 3508 (class 2606 OID 32815)
-- Name: rekv rekv_pkey; Type: CONSTRAINT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.rekv
    ADD CONSTRAINT rekv_pkey PRIMARY KEY (id);


--
-- TOC entry 3520 (class 2606 OID 49201)
-- Name: taotlus_login taotlus_login_pkey; Type: CONSTRAINT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.taotlus_login
    ADD CONSTRAINT taotlus_login_pkey PRIMARY KEY (id);


--
-- TOC entry 3505 (class 2606 OID 32801)
-- Name: userid userid_pkey; Type: CONSTRAINT; Schema: ou; Owner: postgres
--

ALTER TABLE ONLY ou.userid
    ADD CONSTRAINT userid_pkey PRIMARY KEY (id);


--
-- TOC entry 3511 (class 2606 OID 32834)
-- Name: session session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (sid);


--
-- TOC entry 3574 (class 1259 OID 122921)
-- Name: arv1_nomid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX arv1_nomid ON docs.arv1 USING btree (nomid);


--
-- TOC entry 3575 (class 1259 OID 122922)
-- Name: arv1_parentid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX arv1_parentid ON docs.arv1 USING btree (parentid);


--
-- TOC entry 3580 (class 1259 OID 122975)
-- Name: arvtasu_doc_arv_id; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX arvtasu_doc_arv_id ON docs.arvtasu USING btree (doc_arv_id);


--
-- TOC entry 3581 (class 1259 OID 122976)
-- Name: arvtasu_doc_tasu_id; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX arvtasu_doc_tasu_id ON docs.arvtasu USING btree (doc_tasu_id);


--
-- TOC entry 3582 (class 1259 OID 122977)
-- Name: arvtasu_kpv; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX arvtasu_kpv ON docs.arvtasu USING btree (kpv);


--
-- TOC entry 3570 (class 1259 OID 118072)
-- Name: idx_arv_asutusid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_arv_asutusid ON docs.arv USING btree (asutusid);


--
-- TOC entry 3571 (class 1259 OID 118073)
-- Name: idx_arv_kpv; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_arv_kpv ON docs.arv USING btree (kpv);


--
-- TOC entry 3572 (class 1259 OID 118070)
-- Name: idx_arv_parentid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_arv_parentid ON docs.arv USING btree (parentid);


--
-- TOC entry 3573 (class 1259 OID 118071)
-- Name: idx_arv_rekvid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_arv_rekvid ON docs.arv USING btree (rekvid);


--
-- TOC entry 3585 (class 1259 OID 122978)
-- Name: idx_arvtasu_tasu; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE UNIQUE INDEX idx_arvtasu_tasu ON docs.arvtasu USING btree (doc_tasu_id, doc_arv_id) WHERE (status <> 3);


--
-- TOC entry 3523 (class 1259 OID 49215)
-- Name: idx_doc_status; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_doc_status ON docs.doc USING btree (status);


--
-- TOC entry 3524 (class 1259 OID 49216)
-- Name: idx_doc_typ_id; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_doc_typ_id ON docs.doc USING btree (doc_type_id) WHERE (status <> 3);


--
-- TOC entry 3592 (class 1259 OID 172432)
-- Name: idx_mk1_asutusid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_mk1_asutusid ON docs.mk1 USING btree (asutusid);


--
-- TOC entry 3593 (class 1259 OID 172433)
-- Name: idx_mk1_nomidid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_mk1_nomidid ON docs.mk1 USING btree (nomid);


--
-- TOC entry 3594 (class 1259 OID 172431)
-- Name: idx_mk1_parentid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX idx_mk1_parentid ON docs.mk1 USING btree (parentid);


--
-- TOC entry 3597 (class 1259 OID 172612)
-- Name: korder1_asuitus_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX korder1_asuitus_idx ON docs.korder1 USING btree (asutusid);


--
-- TOC entry 3598 (class 1259 OID 172609)
-- Name: korder1_kpv_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX korder1_kpv_idx ON docs.korder1 USING btree (kpv);


--
-- TOC entry 3599 (class 1259 OID 172610)
-- Name: korder1_number_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX korder1_number_idx ON docs.korder1 USING btree (number);


--
-- TOC entry 3600 (class 1259 OID 172611)
-- Name: korder1_parent_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX korder1_parent_idx ON docs.korder1 USING btree (parentid);


--
-- TOC entry 3603 (class 1259 OID 172608)
-- Name: korder1_rekv_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX korder1_rekv_idx ON docs.korder1 USING btree (rekvid);


--
-- TOC entry 3604 (class 1259 OID 172629)
-- Name: korder2_nomid_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX korder2_nomid_idx ON docs.korder2 USING btree (nomid);


--
-- TOC entry 3605 (class 1259 OID 172628)
-- Name: korder2_parentid_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX korder2_parentid_idx ON docs.korder2 USING btree (parentid);


--
-- TOC entry 3541 (class 1259 OID 106544)
-- Name: leping1_asutusid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX leping1_asutusid ON docs.leping1 USING btree (asutusid);


--
-- TOC entry 3542 (class 1259 OID 106543)
-- Name: leping1_parentid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX leping1_parentid ON docs.leping1 USING btree (parentid);


--
-- TOC entry 3543 (class 1259 OID 114751)
-- Name: leping1_parentid_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE UNIQUE INDEX leping1_parentid_idx ON docs.leping1 USING btree (parentid);


--
-- TOC entry 3546 (class 1259 OID 106545)
-- Name: leping1_rekvid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX leping1_rekvid ON docs.leping1 USING btree (rekvid);


--
-- TOC entry 3553 (class 1259 OID 114715)
-- Name: leping2_nomid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX leping2_nomid ON docs.leping2 USING btree (nomid);


--
-- TOC entry 3554 (class 1259 OID 114716)
-- Name: leping2_parentid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX leping2_parentid ON docs.leping2 USING btree (parentid);


--
-- TOC entry 3586 (class 1259 OID 172415)
-- Name: mk_maksepaev_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX mk_maksepaev_idx ON docs.mk USING btree (maksepaev);


--
-- TOC entry 3587 (class 1259 OID 172417)
-- Name: mk_opt_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX mk_opt_idx ON docs.mk USING btree (opt);


--
-- TOC entry 3588 (class 1259 OID 172414)
-- Name: mk_parentid_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX mk_parentid_idx ON docs.mk USING btree (parentid);


--
-- TOC entry 3591 (class 1259 OID 172416)
-- Name: mk_rekvid_idx; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX mk_rekvid_idx ON docs.mk USING btree (rekvid);


--
-- TOC entry 3557 (class 1259 OID 114750)
-- Name: moodu1_lepingid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX moodu1_lepingid ON docs.moodu1 USING btree (lepingid);


--
-- TOC entry 3558 (class 1259 OID 114749)
-- Name: moodu1_parentid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX moodu1_parentid ON docs.moodu1 USING btree (parentid);


--
-- TOC entry 3561 (class 1259 OID 114767)
-- Name: moodu2_nomid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX moodu2_nomid ON docs.moodu2 USING btree (nomid);


--
-- TOC entry 3562 (class 1259 OID 114768)
-- Name: moodu2_parentid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX moodu2_parentid ON docs.moodu2 USING btree (parentid);


--
-- TOC entry 3608 (class 1259 OID 196769)
-- Name: rekl_asutusid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX rekl_asutusid ON docs.rekl USING btree (asutusid) WHERE (status <> 3);


--
-- TOC entry 3611 (class 1259 OID 196768)
-- Name: rekl_rekvid; Type: INDEX; Schema: docs; Owner: postgres
--

CREATE INDEX rekl_rekvid ON docs.rekl USING btree (rekvid) WHERE (status <> 3);


--
-- TOC entry 3529 (class 1259 OID 91095)
-- Name: asutus_kasutaja; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX asutus_kasutaja ON libs.asutus USING btree (kasutaja, omvorm) WHERE (staatus <> 3);


--
-- TOC entry 3530 (class 1259 OID 90793)
-- Name: asutus_nimetus; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX asutus_nimetus ON libs.asutus USING btree (nimetus, omvorm) WHERE (staatus <> 3);


--
-- TOC entry 3533 (class 1259 OID 90795)
-- Name: asutus_staatus; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX asutus_staatus ON libs.asutus USING btree (staatus) WHERE (staatus <> 3);


--
-- TOC entry 3535 (class 1259 OID 98342)
-- Name: asutus_user_id_idx; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX asutus_user_id_idx ON libs.asutus_user_id USING btree (user_id, asutus_id);


--
-- TOC entry 3547 (class 1259 OID 106590)
-- Name: dokprop_parentid_idx; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX dokprop_parentid_idx ON libs.dokprop USING btree (parentid);


--
-- TOC entry 3534 (class 1259 OID 90794)
-- Name: kood_asutus; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX kood_asutus ON libs.asutus USING btree (regkood) WHERE (staatus <> 3);


--
-- TOC entry 3512 (class 1259 OID 41012)
-- Name: library_docs_modules; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX library_docs_modules ON libs.library USING btree (((properties ->> 'module'::text))) WHERE (library = 'DOK'::bpchar);


--
-- TOC entry 3513 (class 1259 OID 41013)
-- Name: library_idx_cluster_library; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX library_idx_cluster_library ON libs.library USING btree (library) INCLUDE (library);

ALTER TABLE libs.library CLUSTER ON library_idx_cluster_library;


--
-- TOC entry 3514 (class 1259 OID 41009)
-- Name: library_kood; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX library_kood ON libs.library USING btree (kood) WHERE (status <> 3);


--
-- TOC entry 3515 (class 1259 OID 41010)
-- Name: library_library; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX library_library ON libs.library USING btree (library) WHERE (status <> 3);


--
-- TOC entry 3518 (class 1259 OID 41011)
-- Name: library_rekvid; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX library_rekvid ON libs.library USING btree (rekvid);


--
-- TOC entry 3552 (class 1259 OID 106612)
-- Name: nomenklatuur_rekvid; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX nomenklatuur_rekvid ON libs.nomenklatuur USING btree (rekvid);


--
-- TOC entry 3525 (class 1259 OID 90768)
-- Name: object_asutusid; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX object_asutusid ON libs.object USING btree (asutusid) WHERE (status <> 3);


--
-- TOC entry 3538 (class 1259 OID 98352)
-- Name: object_owner_asutus_id; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX object_owner_asutus_id ON libs.object_owner USING btree (object_id, asutus_id);


--
-- TOC entry 3528 (class 1259 OID 90767)
-- Name: object_rekvid; Type: INDEX; Schema: libs; Owner: postgres
--

CREATE INDEX object_rekvid ON libs.object USING btree (rekvid) WHERE (status <> 3);


--
-- TOC entry 3565 (class 1259 OID 118048)
-- Name: aa_parentid; Type: INDEX; Schema: ou; Owner: postgres
--

CREATE INDEX aa_parentid ON ou.aa USING btree (parentid);


--
-- TOC entry 3506 (class 1259 OID 32802)
-- Name: userid_rekvid; Type: INDEX; Schema: ou; Owner: postgres
--

CREATE INDEX userid_rekvid ON ou.userid USING btree (rekvid, kasutaja);


--
-- TOC entry 3509 (class 1259 OID 32835)
-- Name: IDX_session_expire; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "IDX_session_expire" ON public.session USING btree (expire);


--
-- TOC entry 3768 (class 2618 OID 118074)
-- Name: arv arv_insert_2020; Type: RULE; Schema: docs; Owner: postgres
--

CREATE RULE arv_insert_2020 AS
    ON INSERT TO docs.arv
   WHERE (new.kpv <= '2020-12-31'::date) DO INSTEAD NOTHING;


--
-- TOC entry 3614 (class 2606 OID 114752)
-- Name: moodu1 leping_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.moodu1
    ADD CONSTRAINT leping_id_frk FOREIGN KEY (lepingid) REFERENCES docs.leping1(parentid) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 3613 (class 2606 OID 114717)
-- Name: leping2 parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.leping2
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.leping1(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3615 (class 2606 OID 114769)
-- Name: moodu2 parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.moodu2
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.moodu1(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3616 (class 2606 OID 118075)
-- Name: arv parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.arv
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.doc(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3617 (class 2606 OID 172418)
-- Name: mk parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.mk
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.doc(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3618 (class 2606 OID 172434)
-- Name: mk1 parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.mk1
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.mk(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3619 (class 2606 OID 172613)
-- Name: korder1 parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.korder1
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.doc(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3620 (class 2606 OID 172630)
-- Name: korder2 parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.korder2
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.korder1(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3621 (class 2606 OID 196770)
-- Name: rekl parent_id_frk; Type: FK CONSTRAINT; Schema: docs; Owner: postgres
--

ALTER TABLE ONLY docs.rekl
    ADD CONSTRAINT parent_id_frk FOREIGN KEY (parentid) REFERENCES docs.doc(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3612 (class 2606 OID 106591)
-- Name: dokprop dokprop_parent; Type: FK CONSTRAINT; Schema: libs; Owner: postgres
--

ALTER TABLE ONLY libs.dokprop
    ADD CONSTRAINT dokprop_parent FOREIGN KEY (parentid) REFERENCES libs.library(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3992 (class 0 OID 0)
-- Dependencies: 3612
-- Name: CONSTRAINT dokprop_parent ON dokprop; Type: COMMENT; Schema: libs; Owner: postgres
--

COMMENT ON CONSTRAINT dokprop_parent ON libs.dokprop IS 'Сылка на тип документа';


--
-- TOC entry 3834 (class 0 OID 0)
-- Dependencies: 317
-- Name: FUNCTION check_arv_jaak(tnid integer, user_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.check_arv_jaak(tnid integer, user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3835 (class 0 OID 0)
-- Dependencies: 308
-- Name: FUNCTION create_new_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.create_new_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) TO db;


--
-- TOC entry 3836 (class 0 OID 0)
-- Dependencies: 327
-- Name: FUNCTION create_new_order(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.create_new_order(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) TO db;


--
-- TOC entry 3837 (class 0 OID 0)
-- Dependencies: 294
-- Name: FUNCTION create_number_sequence(l_rekvid integer, l_dok text, l_found_last_num boolean); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.create_number_sequence(l_rekvid integer, l_dok text, l_found_last_num boolean) TO db;


--
-- TOC entry 3838 (class 0 OID 0)
-- Dependencies: 310
-- Name: FUNCTION create_return_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.create_return_mk(user_id integer, params jsonb, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text) TO db;


--
-- TOC entry 3839 (class 0 OID 0)
-- Dependencies: 296
-- Name: FUNCTION year(date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.year(date) TO db;


--
-- TOC entry 3840 (class 0 OID 0)
-- Dependencies: 291
-- Name: FUNCTION kaive_aruanne(l_rekvid integer, kpv_start date, kpv_end date); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.kaive_aruanne(l_rekvid integer, kpv_start date, kpv_end date) TO db;


--
-- TOC entry 3841 (class 0 OID 0)
-- Dependencies: 315
-- Name: FUNCTION koosta_arve_lepingu_alusel(user_id integer, l_leping_id integer, l_kpv date, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text, OUT viitenr text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.koosta_arve_lepingu_alusel(user_id integer, l_leping_id integer, l_kpv date, OUT error_code integer, OUT result integer, OUT doc_type_id text, OUT error_message text, OUT viitenr text) TO db;


--
-- TOC entry 3842 (class 0 OID 0)
-- Dependencies: 321
-- Name: FUNCTION sp_delete_arvtasu(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_delete_arvtasu(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3843 (class 0 OID 0)
-- Dependencies: 316
-- Name: FUNCTION sp_delete_korder(user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_delete_korder(user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3844 (class 0 OID 0)
-- Dependencies: 314
-- Name: FUNCTION sp_delete_leping(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_delete_leping(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3845 (class 0 OID 0)
-- Dependencies: 323
-- Name: FUNCTION sp_delete_mk(l_user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_delete_mk(l_user_id integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3846 (class 0 OID 0)
-- Dependencies: 295
-- Name: FUNCTION sp_get_number(l_rekvid integer, l_dok text, l_year integer, l_dokpropid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_get_number(l_rekvid integer, l_dok text, l_year integer, l_dokpropid integer) TO db;


--
-- TOC entry 3848 (class 0 OID 0)
-- Dependencies: 307
-- Name: FUNCTION sp_loe_arv(l_arv_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_loe_arv(l_arv_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3850 (class 0 OID 0)
-- Dependencies: 324
-- Name: FUNCTION sp_loe_tasu(l_tasu_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_loe_tasu(l_tasu_id integer, l_user_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3851 (class 0 OID 0)
-- Dependencies: 318
-- Name: FUNCTION sp_salvesta_arv(data json, user_id integer, user_rekvid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_salvesta_arv(data json, user_id integer, user_rekvid integer) TO db;


--
-- TOC entry 3852 (class 0 OID 0)
-- Dependencies: 322
-- Name: FUNCTION sp_salvesta_arvtasu(data json, userid integer, user_rekvid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_salvesta_arvtasu(data json, userid integer, user_rekvid integer) TO db;


--
-- TOC entry 3853 (class 0 OID 0)
-- Dependencies: 319
-- Name: FUNCTION sp_salvesta_korder(data json, userid integer, user_rekvid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_salvesta_korder(data json, userid integer, user_rekvid integer) TO db;


--
-- TOC entry 3854 (class 0 OID 0)
-- Dependencies: 306
-- Name: FUNCTION sp_salvesta_leping(data json, userid integer, user_rekvid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_salvesta_leping(data json, userid integer, user_rekvid integer) TO db;


--
-- TOC entry 3855 (class 0 OID 0)
-- Dependencies: 305
-- Name: FUNCTION sp_salvesta_mk(data json, user_id integer, user_rekvid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_salvesta_mk(data json, user_id integer, user_rekvid integer) TO db;


--
-- TOC entry 3856 (class 0 OID 0)
-- Dependencies: 320
-- Name: FUNCTION sp_salvesta_moodu(data json, userid integer, user_rekvid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_salvesta_moodu(data json, userid integer, user_rekvid integer) TO db;


--
-- TOC entry 3857 (class 0 OID 0)
-- Dependencies: 328
-- Name: FUNCTION sp_salvesta_rekl(data json, userid integer, user_rekvid integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_salvesta_rekl(data json, userid integer, user_rekvid integer) TO db;


--
-- TOC entry 3858 (class 0 OID 0)
-- Dependencies: 309
-- Name: FUNCTION sp_tasu_arv(l_tasu_id integer, l_arv_id integer, l_user_id integer, tasu_summa numeric); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_tasu_arv(l_tasu_id integer, l_arv_id integer, l_user_id integer, tasu_summa numeric) TO db;


--
-- TOC entry 3859 (class 0 OID 0)
-- Dependencies: 326
-- Name: FUNCTION sp_update_arv_jaak(l_arv_id integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_update_arv_jaak(l_arv_id integer) TO db;


--
-- TOC entry 3860 (class 0 OID 0)
-- Dependencies: 290
-- Name: FUNCTION sp_update_mk_jaak(l_mk_id integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.sp_update_mk_jaak(l_mk_id integer) TO db;


--
-- TOC entry 3861 (class 0 OID 0)
-- Dependencies: 325
-- Name: FUNCTION update_last_rekl(tnid integer, OUT result integer); Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON FUNCTION docs.update_last_rekl(tnid integer, OUT result integer) TO db;


--
-- TOC entry 3862 (class 0 OID 0)
-- Dependencies: 311
-- Name: FUNCTION sp_delete_asutus(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON FUNCTION libs.sp_delete_asutus(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3863 (class 0 OID 0)
-- Dependencies: 299
-- Name: FUNCTION sp_delete_nomenclature(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON FUNCTION libs.sp_delete_nomenclature(userid integer, doc_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3864 (class 0 OID 0)
-- Dependencies: 312
-- Name: FUNCTION sp_salvesta_asutus(data json, userid integer, user_rekvid integer); Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON FUNCTION libs.sp_salvesta_asutus(data json, userid integer, user_rekvid integer) TO db;


--
-- TOC entry 3865 (class 0 OID 0)
-- Dependencies: 304
-- Name: FUNCTION sp_salvesta_nomenclature(data json, userid integer, user_rekvid integer); Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON FUNCTION libs.sp_salvesta_nomenclature(data json, userid integer, user_rekvid integer) TO db;


--
-- TOC entry 3866 (class 0 OID 0)
-- Dependencies: 293
-- Name: FUNCTION get_user_data(l_kasutaja text, l_rekvid integer, l_module text); Type: ACL; Schema: ou; Owner: postgres
--

GRANT ALL ON FUNCTION ou.get_user_data(l_kasutaja text, l_rekvid integer, l_module text) TO db;


--
-- TOC entry 3867 (class 0 OID 0)
-- Dependencies: 313
-- Name: FUNCTION kinnita_taotlus(user_id integer, l_id integer, OUT error_code integer, OUT result integer, OUT error_message text); Type: ACL; Schema: ou; Owner: postgres
--

GRANT ALL ON FUNCTION ou.kinnita_taotlus(user_id integer, l_id integer, OUT error_code integer, OUT result integer, OUT error_message text) TO db;


--
-- TOC entry 3868 (class 0 OID 0)
-- Dependencies: 298
-- Name: FUNCTION sp_salvesta_taotlus_login(data json, l_user_id integer, l_rekv_id integer); Type: ACL; Schema: ou; Owner: postgres
--

GRANT ALL ON FUNCTION ou.sp_salvesta_taotlus_login(data json, l_user_id integer, l_rekv_id integer) TO db;


--
-- TOC entry 3869 (class 0 OID 0)
-- Dependencies: 301
-- Name: FUNCTION empty(date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.empty(date) TO db;


--
-- TOC entry 3870 (class 0 OID 0)
-- Dependencies: 302
-- Name: FUNCTION empty(integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.empty(integer) TO db;


--
-- TOC entry 3871 (class 0 OID 0)
-- Dependencies: 303
-- Name: FUNCTION empty(numeric); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.empty(numeric) TO db;


--
-- TOC entry 3872 (class 0 OID 0)
-- Dependencies: 300
-- Name: FUNCTION empty(character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.empty(character varying) TO db;


--
-- TOC entry 3873 (class 0 OID 0)
-- Dependencies: 297
-- Name: FUNCTION month(date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.month(date) TO db;


--
-- TOC entry 3874 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE arv; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.arv TO db;


--
-- TOC entry 3875 (class 0 OID 0)
-- Dependencies: 257
-- Name: TABLE arv1; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.arv1 TO db;


--
-- TOC entry 3877 (class 0 OID 0)
-- Dependencies: 256
-- Name: SEQUENCE arv1_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.arv1_id_seq TO db;


--
-- TOC entry 3879 (class 0 OID 0)
-- Dependencies: 254
-- Name: SEQUENCE arv_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.arv_id_seq TO db;


--
-- TOC entry 3880 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE arvtasu; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.arvtasu TO db;


--
-- TOC entry 3882 (class 0 OID 0)
-- Dependencies: 260
-- Name: SEQUENCE arvtasu_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.arvtasu_id_seq TO db;


--
-- TOC entry 3886 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE doc; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.doc TO db;


--
-- TOC entry 3888 (class 0 OID 0)
-- Dependencies: 223
-- Name: SEQUENCE doc_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.doc_id_seq TO db;


--
-- TOC entry 3889 (class 0 OID 0)
-- Dependencies: 269
-- Name: TABLE korder1; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.korder1 TO db;


--
-- TOC entry 3891 (class 0 OID 0)
-- Dependencies: 268
-- Name: SEQUENCE korder1_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.korder1_id_seq TO db;


--
-- TOC entry 3892 (class 0 OID 0)
-- Dependencies: 271
-- Name: TABLE korder2; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.korder2 TO db;


--
-- TOC entry 3894 (class 0 OID 0)
-- Dependencies: 270
-- Name: SEQUENCE korder2_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.korder2_id_seq TO db;


--
-- TOC entry 3895 (class 0 OID 0)
-- Dependencies: 237
-- Name: TABLE leping1; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.leping1 TO db;


--
-- TOC entry 3897 (class 0 OID 0)
-- Dependencies: 236
-- Name: SEQUENCE leping1_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.leping1_id_seq TO db;


--
-- TOC entry 3898 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE leping2; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.leping2 TO db;


--
-- TOC entry 3900 (class 0 OID 0)
-- Dependencies: 244
-- Name: SEQUENCE leping2_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.leping2_id_seq TO db;


--
-- TOC entry 3901 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE mk; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.mk TO db;


--
-- TOC entry 3902 (class 0 OID 0)
-- Dependencies: 267
-- Name: TABLE mk1; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.mk1 TO db;


--
-- TOC entry 3904 (class 0 OID 0)
-- Dependencies: 266
-- Name: SEQUENCE mk1_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.mk1_id_seq TO db;


--
-- TOC entry 3906 (class 0 OID 0)
-- Dependencies: 264
-- Name: SEQUENCE mk_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.mk_id_seq TO db;


--
-- TOC entry 3907 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE moodu1; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.moodu1 TO db;


--
-- TOC entry 3909 (class 0 OID 0)
-- Dependencies: 247
-- Name: SEQUENCE moodu1_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.moodu1_id_seq TO db;


--
-- TOC entry 3910 (class 0 OID 0)
-- Dependencies: 250
-- Name: TABLE moodu2; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.moodu2 TO db;


--
-- TOC entry 3912 (class 0 OID 0)
-- Dependencies: 249
-- Name: SEQUENCE moodu2_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.moodu2_id_seq TO db;


--
-- TOC entry 3913 (class 0 OID 0)
-- Dependencies: 278
-- Name: TABLE rekl; Type: ACL; Schema: docs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE docs.rekl TO db;


--
-- TOC entry 3915 (class 0 OID 0)
-- Dependencies: 277
-- Name: SEQUENCE rekl_id_seq; Type: ACL; Schema: docs; Owner: postgres
--

GRANT ALL ON SEQUENCE docs.rekl_id_seq TO db;


--
-- TOC entry 3916 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE asutus; Type: ACL; Schema: libs; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE libs.asutus TO db;


--
-- TOC entry 3918 (class 0 OID 0)
-- Dependencies: 229
-- Name: SEQUENCE asutus_id_seq; Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON SEQUENCE libs.asutus_id_seq TO db;


--
-- TOC entry 3919 (class 0 OID 0)
-- Dependencies: 233
-- Name: TABLE asutus_user_id; Type: ACL; Schema: libs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE libs.asutus_user_id TO db;


--
-- TOC entry 3921 (class 0 OID 0)
-- Dependencies: 232
-- Name: SEQUENCE asutus_user_id_id_seq; Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON SEQUENCE libs.asutus_user_id_id_seq TO db;


--
-- TOC entry 3922 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE dokprop; Type: ACL; Schema: libs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE libs.dokprop TO db;


--
-- TOC entry 3924 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE library; Type: ACL; Schema: libs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE libs.library TO db;


--
-- TOC entry 3926 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE nomenklatuur; Type: ACL; Schema: libs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE libs.nomenklatuur TO db;


--
-- TOC entry 3928 (class 0 OID 0)
-- Dependencies: 240
-- Name: SEQUENCE nomenklatuur_id_seq; Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON SEQUENCE libs.nomenklatuur_id_seq TO db;


--
-- TOC entry 3929 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE object; Type: ACL; Schema: libs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE libs.object TO db;


--
-- TOC entry 3931 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE object_id_seq; Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON SEQUENCE libs.object_id_seq TO db;


--
-- TOC entry 3932 (class 0 OID 0)
-- Dependencies: 235
-- Name: TABLE object_owner; Type: ACL; Schema: libs; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE libs.object_owner TO db;


--
-- TOC entry 3934 (class 0 OID 0)
-- Dependencies: 234
-- Name: SEQUENCE object_owner_id_seq; Type: ACL; Schema: libs; Owner: postgres
--

GRANT ALL ON SEQUENCE libs.object_owner_id_seq TO db;


--
-- TOC entry 3935 (class 0 OID 0)
-- Dependencies: 253
-- Name: TABLE aa; Type: ACL; Schema: ou; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE ou.aa TO db;


--
-- TOC entry 3937 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE config; Type: ACL; Schema: ou; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE ou.config TO db;


--
-- TOC entry 3939 (class 0 OID 0)
-- Dependencies: 215
-- Name: TABLE rekv; Type: ACL; Schema: ou; Owner: postgres
--

GRANT ALL ON TABLE ou.rekv TO db;


--
-- TOC entry 3940 (class 0 OID 0)
-- Dependencies: 213
-- Name: TABLE userid; Type: ACL; Schema: ou; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE ou.userid TO db;


--
-- TOC entry 3941 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE cur_userid; Type: ACL; Schema: ou; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE ou.cur_userid TO db;


--
-- TOC entry 3943 (class 0 OID 0)
-- Dependencies: 214
-- Name: SEQUENCE rekv_id_seq; Type: ACL; Schema: ou; Owner: postgres
--

GRANT ALL ON SEQUENCE ou.rekv_id_seq TO db;


--
-- TOC entry 3944 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE taotlus_login; Type: ACL; Schema: ou; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE ou.taotlus_login TO db;


--
-- TOC entry 3946 (class 0 OID 0)
-- Dependencies: 221
-- Name: SEQUENCE taotlus_login_id_seq; Type: ACL; Schema: ou; Owner: postgres
--

GRANT ALL ON SEQUENCE ou.taotlus_login_id_seq TO db;


--
-- TOC entry 3948 (class 0 OID 0)
-- Dependencies: 212
-- Name: SEQUENCE userid_id_seq; Type: ACL; Schema: ou; Owner: postgres
--

GRANT ALL ON SEQUENCE ou.userid_id_seq TO db;


--
-- TOC entry 3949 (class 0 OID 0)
-- Dependencies: 262
-- Name: SEQUENCE arv_1_number; Type: ACL; Schema: public; Owner: db
--

GRANT ALL ON SEQUENCE public.arv_1_number TO PUBLIC;


--
-- TOC entry 3950 (class 0 OID 0)
-- Dependencies: 275
-- Name: TABLE com_arved; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.com_arved TO db;


--
-- TOC entry 3951 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE com_asutused; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.com_asutused TO db;


--
-- TOC entry 3952 (class 0 OID 0)
-- Dependencies: 243
-- Name: TABLE com_nomenclature; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.com_nomenclature TO db;


--
-- TOC entry 3953 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE com_objekt; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.com_objekt TO db;


--
-- TOC entry 3954 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE cur_arved; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.cur_arved TO db;


--
-- TOC entry 3955 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE cur_asutused; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.cur_asutused TO db;


--
-- TOC entry 3956 (class 0 OID 0)
-- Dependencies: 274
-- Name: TABLE cur_korder; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.cur_korder TO db;


--
-- TOC entry 3957 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE cur_lepingud; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.cur_lepingud TO db;


--
-- TOC entry 3958 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE cur_moodu; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.cur_moodu TO db;


--
-- TOC entry 3959 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE cur_pank; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.cur_pank TO db;


--
-- TOC entry 3960 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE cur_rekv; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.cur_rekv TO db;


--
-- TOC entry 3961 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE session; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.session TO db;


--
-- TOC entry 3962 (class 0 OID 0)
-- Dependencies: 273
-- Name: SEQUENCE smk_1_number; Type: ACL; Schema: public; Owner: db
--

GRANT ALL ON SEQUENCE public.smk_1_number TO PUBLIC;


--
-- TOC entry 3963 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE v_taotlus; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.v_taotlus TO db;


--
-- TOC entry 3964 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE v_user; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.v_user TO db;


--
-- TOC entry 2252 (class 826 OID 41492)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: docs; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA docs REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA docs GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLES  TO db;


--
-- TOC entry 2251 (class 826 OID 40976)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: libs; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA libs REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA libs GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLES  TO db;


--
-- TOC entry 2249 (class 826 OID 32777)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ou; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ou REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ou GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLES  TO db;


--
-- TOC entry 2250 (class 826 OID 40969)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLES  TO db;


-- Completed on 2021-10-28 22:22:26

--
-- PostgreSQL database dump complete
--


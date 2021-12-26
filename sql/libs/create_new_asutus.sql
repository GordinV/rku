DROP FUNCTION IF EXISTS libs.create_new_asutus(INTEGER, JSONB);

CREATE OR REPLACE FUNCTION libs.create_new_asutus(IN user_id INTEGER,
                                                  IN l_params JSONB,
                                                  OUT error_code INTEGER,
                                                  OUT result INTEGER,
                                                  OUT error_message TEXT)
    RETURNS RECORD AS
$BODY$

DECLARE
    l_rekvid    INTEGER = (SELECT rekvid
                           FROM ou.userid u
                           WHERE id = user_id
                           LIMIT 1);
    l_regkood   TEXT    = l_params ->> 'regkood';
    l_nimetus   TEXT    = l_params ->> 'nimetus';
    l_aa        TEXT    = l_params ->> 'aa';
    l_omvorm    TEXT    = coalesce((l_params ->> 'omvorm')::TEXT, 'ISIK');

    json_object JSONB;
    l_row_id    INTEGER;
    v_asutus    RECORD;
BEGIN

    -- ищем по расч. счету
    IF l_aa IS NOT NULL
    THEN
        l_row_id = (SELECT a.id
                    FROM libs.asutus a,
                         json_array_elements(CASE
                                                 WHEN (a.properties ->> 'asutus_aa') IS NULL THEN '[]'::JSON
                                                 ELSE (a.properties -> 'asutus_aa') :: JSON END) AS e (element)
                    WHERE (e.element ->> 'aa') = l_aa
                    ORDER BY id DESC
                    LIMIT 1);
    END IF;

    -- ищем по коду
    IF l_row_id is null and l_regkood IS NOT NULL
    THEN
        l_row_id = (SELECT id
                    FROM libs.asutus a
                    WHERE regkood::TEXT = l_regkood::TEXT
                    ORDER BY staatus ASC, id DESC
                    LIMIT 1);
    END IF;

    IF (l_row_id IS NOT NULL AND l_row_id > 0)
    THEN
        -- такая запись уже есть, вернем ссылку на нее
        result = l_row_id;
        error_message = 'kaart selle koodiga juba olemas';
        RETURN;
    END IF;

    SELECT l_regkood                      AS regkood,
           l_nimetus                      AS nimetus,
           ('[{"aa":"' ||  l_aa || '"}]')::jsonb AS asutus_aa,
           l_omvorm                       AS omvorm
    INTO v_asutus;

    -- подготавливаем параметры для сохранения
    SELECT row_to_json(row)
    INTO json_object
    FROM (SELECT 0                             AS id,
                 (SELECT to_jsonb(v_asutus.*)) AS data) row;

    SELECT libs.sp_salvesta_asutus(json_object :: JSON, user_id, l_rekvid) INTO l_row_id;

    IF l_row_id IS NOT NULL
    THEN
        result = l_row_id ;
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
END ;
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION libs.create_new_asutus(INTEGER, JSONB) TO db;


/*
select lapsed.arvesta_taabel(70, 16,'2019-01-30')

 */
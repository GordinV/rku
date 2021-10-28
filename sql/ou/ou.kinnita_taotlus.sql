DROP FUNCTION IF EXISTS ou.kinnita_taotlus(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION ou.kinnita_taotlus(IN user_id INTEGER, IN l_id INTEGER,
                                              OUT error_code INTEGER,
                                              OUT result INTEGER,
                                              OUT error_message TEXT)
    RETURNS RECORD AS
$BODY$
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
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION ou.kinnita_taotlus(INTEGER,INTEGER) TO db;

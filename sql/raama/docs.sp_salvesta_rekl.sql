DROP FUNCTION IF EXISTS docs.sp_salvesta_rekl(JSON, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION docs.sp_salvesta_rekl(data JSON,
                                                 userid INTEGER,
                                                 user_rekvid INTEGER)
    RETURNS INTEGER AS
$BODY$

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
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.sp_salvesta_rekl(JSON, INTEGER, INTEGER) TO db;

/*
select docs.sp_salvesta_leping('{"id":297260,"data": {"asutusid":1,"bpm":null,"created":"10.08.2018 11:08:13","doc":"Lepingud","doc_status":0,"doc_type_id":"LEPING","dok":null,"doklausid":null,"id":297260,"kpv":"2018-08-10","lastupdate":"10.08.2018 11:08:13","number":"001","objektid":null,"pakettid":null,"rekvid":1,"selgitus":"test 123","status":"????????","tahtaeg":"2018-08-10","userid":1,"gridData":[{"hind":100,"id":4,"kbm":0,"kogus":1,"kood":"TEENUS18","nimetus":"Teenuse selgitus   18%","nomid":2,"soodus":0,"soodusalg":"        ","sooduslopp":"        ","status":1,"summa":100,"userid":1}]}}'
, 1, 1);
*/

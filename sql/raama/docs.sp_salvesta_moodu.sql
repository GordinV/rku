DROP FUNCTION IF EXISTS docs.sp_salvesta_moodu(JSON, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION docs.sp_salvesta_moodu(data JSON,
                                                  userid INTEGER,
                                                  user_rekvid INTEGER)
    RETURNS INTEGER AS
$BODY$

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
                         json_object) AS x(id TEXT, nomid INTEGER, kogus NUMERIC(14, 4), hind NUMERIC(14, 4),
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
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.sp_salvesta_moodu(JSON, INTEGER, INTEGER) TO db;

/*
select docs.sp_salvesta_leping('{"id":297260,"data": {"asutusid":1,"bpm":null,"created":"10.08.2018 11:08:13","doc":"Lepingud","doc_status":0,"doc_type_id":"LEPING","dok":null,"doklausid":null,"id":297260,"kpv":"2018-08-10","lastupdate":"10.08.2018 11:08:13","number":"001","objektid":null,"pakettid":null,"rekvid":1,"selgitus":"test 123","status":"????????","tahtaeg":"2018-08-10","userid":1,"gridData":[{"hind":100,"id":4,"kbm":0,"kogus":1,"kood":"TEENUS18","nimetus":"Teenuse selgitus   18%","nomid":2,"soodus":0,"soodusalg":"        ","sooduslopp":"        ","status":1,"summa":100,"userid":1}]}}'
, 1, 1);
*/

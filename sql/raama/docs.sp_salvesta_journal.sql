﻿DROP FUNCTION IF EXISTS docs.sp_salvesta_journal(JSON, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION docs.sp_salvesta_journal(data JSON,
                                                    userid INTEGER,
                                                    user_rekvid INTEGER)
    RETURNS INTEGER AS
$BODY$

DECLARE
    journal_id       INTEGER;
    journal1_id      INTEGER;
    userName         TEXT;
    doc_id           INTEGER = data ->> 'id';
    doc_type_kood    TEXT    = 'JOURNAL'/*data->>'doc_type_id'*/;
    doc_type_id      INTEGER = (SELECT id
                                FROM libs.library
                                WHERE kood = doc_type_kood
                                  AND library = 'DOK'
                                LIMIT 1);
    doc_data         JSON    = data ->> 'data';
    doc_details      JSON    = coalesce(doc_data ->> 'gridData', doc_data ->> 'griddata');
    doc_asutusid     INTEGER = doc_data ->> 'asutusid';
    doc_dok          TEXT    = doc_data ->> 'dok';
    doc_objekt       TEXT    = doc_data ->> 'objekt';
    doc_kpv          DATE    = doc_data ->> 'kpv';
    doc_selg         TEXT    = doc_data ->> 'selg';
    doc_muud         TEXT    = doc_data ->> 'muud';
    l_number         INTEGER = coalesce((SELECT max(number) + 1
                                         FROM docs.journalid
                                         WHERE rekvId = user_rekvid
                                           AND aasta = (date_part('year' :: TEXT, doc_kpv) :: INTEGER)), 1);
    json_object      JSON;
    json_lausend     JSON;

    json_params      JSON;
    json_record      RECORD;
    new_history      JSONB;
    ids              INTEGER[];
    lnId             INTEGER;
    is_import        BOOLEAN = data ->> 'import';
    is_rekl_ettemaks BOOLEAN = FALSE;
    l_prev_kpv       DATE;
    l_arv_id         INTEGER; --ид счета, если проводка является оплатой
    l_oma_tp         TEXT    = (SELECT tp
                                FROM ou.aa
                                WHERE parentid = user_rekvid
                                  AND kassa = 2
                                LIMIT 1);

    l_check_lausend  TEXT;
    l_avans_id       INTEGER;
    l_db_tp          VARCHAR(20);
    l_kr_tp          VARCHAR(20);
BEGIN

    SELECT kasutaja,
           rekvid
    INTO userName
    FROM ou.userid u
    WHERE u.rekvid = user_rekvid
      AND u.id = userId;
    IF is_import IS NULL AND userName IS NULL
    THEN
        RAISE EXCEPTION 'Kasutaja ei leidnud või puuduvad õigused %', user;
    END IF;

    IF (doc_id IS NULL)
    THEN
        doc_id = doc_data ->> 'id';
    END IF;


    -- вставка или апдейт docs.doc
    IF doc_id IS NULL OR doc_id = 0 OR NOT exists(SELECT id
                                                  FROM cur_journal
                                                  WHERE id = doc_id)
    THEN

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS created,
                     userName AS user) row;


        INSERT INTO docs.doc (doc_type_id, history, rekvid, status)
        VALUES (doc_type_id, '[]' :: JSONB || new_history, user_rekvid, 1);
        --RETURNING id INTO doc_id;
        SELECT currval('docs.doc_id_seq') INTO doc_id;

        INSERT INTO docs.journal (parentid, rekvid, userid, kpv, asutusid, dok, selg, muud, objekt)
        VALUES (doc_id, user_rekvid, userId, doc_kpv, doc_asutusid, doc_dok, doc_selg, doc_muud,
                doc_objekt);
--                RETURNING id INTO journal_id;
        SELECT currval('docs.journal_id_seq') INTO journal_id;


        INSERT INTO docs.journalid (journalid, rekvid, aasta, number)
        VALUES (journal_id, user_rekvid, (date_part('year' :: TEXT, doc_kpv) :: INTEGER), l_number);

    ELSE

        -- проерка "старого" периода
        SELECT kpv INTO l_prev_kpv FROM docs.journal WHERE id = journal_id;

/*        IF NOT ou.fnc_aasta_kontrol(user_rekvid, coalesce(l_prev_kpv, doc_kpv)) AND NOT is_import
        THEN
            RAISE EXCEPTION 'Period on kinni';
        END IF;
*/

        SELECT row_to_json(row)
        INTO new_history
        FROM (SELECT now()    AS updated,
                     userName AS user) row;

        UPDATE docs.doc
        SET lastupdate = now(),
            history    = coalesce(history, '[]') :: JSONB || new_history
        WHERE id = doc_id;

        UPDATE docs.journal
        SET kpv      = doc_kpv,
            asutusid = doc_asutusid,
            dok      = doc_dok,
            objekt   = doc_objekt,
            muud     = doc_muud,
            selg     = doc_selg
        WHERE parentid = doc_id RETURNING id
            INTO journal_id;

    END IF;
    -- вставка в таблицы документа

    FOR json_object IN
        SELECT *
        FROM json_array_elements(doc_details)
        LOOP
            SELECT *
            INTO json_record
            FROM json_to_record(
                         json_object) AS x (id TEXT, summa NUMERIC(14, 4), deebet TEXT, kreedit TEXT,
                                            tunnus TEXT, proj TEXT);

            IF json_record.summa <> 0
            THEN


                IF json_record.id IS NULL OR json_record.id = '0' OR substring(json_record.id FROM 1 FOR 3) = 'NEW' OR
                   NOT exists(SELECT id
                              FROM docs.journal1
                              WHERE id = json_record.id :: INTEGER)
                THEN
                    INSERT INTO docs.journal1 (parentid, deebet, kreedit, summa, tunnus, proj)
                    VALUES (journal_id, json_record.deebet, json_record.kreedit, json_record.summa, json_record.tunnus,
                            json_record.proj);
--                            RETURNING id INTO journal1_id;
                    SELECT currval('docs.journal1_id_seq') INTO journal1_id;


                    -- add new id into array of ids
                    ids = array_append(ids, journal1_id);

                ELSE

                    UPDATE docs.journal1
                    SET deebet   = json_record.deebet,
                        kreedit  = json_record.kreedit,
                        summa    = json_record.summa,
                        tunnus   = json_record.tunnus,
                        proj     = json_record.proj
                    WHERE id = json_record.id :: INTEGER;

                    journal1_id = json_record.id :: INTEGER;

                    -- add existing id into array of ids
                    ids = array_append(ids, journal1_id);
                END IF;

            END IF;

            -- avans
/*            SELECT a1.parentid
            INTO lnId
            FROM docs.avans1 a1
                     INNER JOIN libs.dokprop d ON d.id = a1.dokpropid
            WHERE ltrim(rtrim(a1.number::TEXT)) = ltrim(rtrim(doc_dok::TEXT))
              AND a1.rekvid = user_rekvid
              AND a1.asutusId = doc_asutusid
              AND (ltrim(rtrim((d.details :: JSONB ->> 'konto')::TEXT)) = ltrim(rtrim(json_record.deebet)) OR
                   ltrim(rtrim((d.details :: JSONB ->> 'konto')::TEXT)) = ltrim(rtrim(json_record.kreedit)))
            ORDER BY a1.kpv
                DESC
            LIMIT 1;

            IF lnId IS NOT NULL
            THEN

                PERFORM docs.get_avans_jaak(lnId);
            END IF;

            IF (json_record.kreedit = '200060' OR json_record.kreedit = '200095') AND doc_selg <> 'Alg.saldo kreedit'
            THEN
                is_rekl_ettemaks = TRUE;
            END IF;
              
*/        
            END LOOP;

    -- delete record which not in json

    DELETE
    FROM docs.journal1
    WHERE parentid = journal_id
      AND id NOT IN (SELECT unnest(ids));


    -- arve tasumine

    l_arv_id = (SELECT d.id
                FROM docs.arv a
                         INNER JOIN docs.doc d ON a.parentid = d.id
                WHERE a.asutusid = doc_asutusid
                  AND number = doc_dok
                  AND a.rekvid = user_rekvid
                  AND a.journalid <> doc_id
                ORDER BY a.jaak DESC
                        , a.kpv
                LIMIT 1
    );

    IF is_import IS NULL AND l_arv_id IS NOT NULL
    THEN
        PERFORM docs.sp_tasu_arv(
                        doc_id, l_arv_id, userid);
    END IF;


--avans
/*    SELECT a1.parentid
    INTO l_avans_id
    FROM docs.avans1 a1
             INNER JOIN libs.dokprop d ON d.id = a1.dokpropid
    WHERE ltrim(rtrim(number::TEXT)) = ltrim(rtrim(doc_dok::TEXT))
      AND a1.rekvid = user_rekvid
      AND a1.asutusId = doc_asutusid
      AND ltrim(rtrim(coalesce((d.details :: JSONB ->> 'konto'), '') :: TEXT)) IN ('202050')
    ORDER BY a1.kpv DESC
    LIMIT 1;

    IF l_avans_id IS NOT NULL
    THEN
        PERFORM docs.get_avans_jaak(l_avans_id);
    END IF;
*/

    RETURN doc_id;

END;
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;


GRANT EXECUTE ON FUNCTION docs.sp_salvesta_journal(JSON, INTEGER, INTEGER) TO db;

/*

select docs.sp_salvesta_journal('{"data":{"id":0,"doc_type_id":"JOURNAL","kpv":"2018-03-04","selg":"Kulum","muud":null,"dok":"Inv.number RCT_76861","asutusid":null,"gridData":[{"id":0,"summa":100.0000,"valuuta":"EUR","kuurs":1.0000,"deebet":"5001","lisa_d":"800599","kreedit":"133","lisa_k":"800401","tunnus":"","proj":"","kood1":"","kood2":"","kood3":"","kood4":"","kood5":""}]}}'
,1, 1);

{"data":{"id":1436,"doc_type_id":"JOURNAL","kpv":"2018-05-17","selg":"Palk","muud":"test","asutusid":56},"gridData":[{"id":0,"summa":289.2000,"deebet":"2610","lisa_d":"800699","kreedit":"2530","lisa_k":"800699","tunnus":null,"proj":"","kood1":"","kood2":"","kood3":"","kood4":"","kood5":""}]}

select * from docs.journal1 where parentid = 14

*/

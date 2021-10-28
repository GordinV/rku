DROP FUNCTION IF EXISTS ou.sp_salvesta_taotlus_login(JSON, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION ou.sp_salvesta_taotlus_login(data JSON,
                                                        l_user_id INTEGER,
                                                        l_rekv_id INTEGER)
    RETURNS INTEGER AS
$BODY$

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
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;


GRANT EXECUTE ON FUNCTION ou.sp_salvesta_taotlus_login(JSON, INTEGER, INTEGER) TO db;

/*
select ou.sp_salvesta_userid('{"id":0,"data":{"ametnik":"Olga Agapova","doc_type_id":"","id":0,"is_admin":0,"is_arvestaja":1,"is_asutuste_korraldaja":0,"is_eel_aktsepterja":0,"is_eel_allkirjastaja":0,"is_eel_esitaja":0,"is_eel_koostaja":0,"is_kasutaja":0,"is_ladu_kasutaja":0,"is_peakasutaja":0,"is_rekl_administraator":0,"is_rekl_maksuhaldur":0,"kasutaja":"olga.agapova","muud":"","parool":"olga","rekvid":0}}'::json, 5155::integer, 85::integer) as id


SELECT ou.sp_salvesta_userid('{"id":0,"data":{"rekvid":1, "kasutaja":"temp_2","ametnik":"test1","is_kasutaja":true}}', 1, 1);

select * from ou.userid where id = 5693

update ou.userid set roles = '{"is_admin":true}' where id = 1

SELECT *
        FROM pg_roles
        WHERE rolname = 'test_2'
*/

﻿DROP FUNCTION IF EXISTS docs.sp_salvesta_asutus(JSON, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION libs.sp_salvesta_asutus(data JSON,
                                                   userid INTEGER,
                                                   user_rekvid INTEGER)
    RETURNS INTEGER
    LANGUAGE 'plpgsql'
AS
$BODY$

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
    doc_asutus_aa  JSONB   = '[]'::jsonb || coalesce((doc_data ->> 'asutus_aa') :: JSONB, coalesce(doc_data ->> 'gridData', doc_data ->> 'griddata'):: JSONB);
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
$BODY$;


GRANT EXECUTE ON FUNCTION libs.sp_salvesta_asutus(JSON, INTEGER, INTEGER) TO db;


/*
select libs.sp_salvesta_asutus('{"id":0,"data":{"aadress":null,"doc_type_id":"TOOTAJA","email":null,"faks":null,"id":0,"is_tootaja":"1","kontakt":null,"mark":null,"muud":null,"nimetus":"vfp tootaja test","omvorm":"ISIK","pank":null,"regkood":"1234_isik_test3367","staatus":0,"tel":null,"tp":"800699","userid":1}}',1, 1);

select * from libs.asutus

*/
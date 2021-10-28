DROP FUNCTION IF EXISTS libs.sp_salvesta_nomenclature(DATA JSON, userid INTEGER, user_rekvid INTEGER);

CREATE OR REPLACE FUNCTION libs.sp_salvesta_nomenclature(data JSON, userid INTEGER, user_rekvid INTEGER)
    RETURNS INTEGER AS
$BODY$

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
$BODY$
    LANGUAGE 'plpgsql'
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION libs.sp_salvesta_nomenclature(DATA JSON, userid INTEGER, user_rekvid INTEGER) TO db;

/*
select libs.sp_salvesta_nomenclature(
'{"id":0,"data":{"allikas":"ALLIKAS","artikkel":"ART","doc_type_id":"VARA","dok":"LADU","formula":null,"gruppid":401,"hind":0,"id":0,"kalor":null,"kogus":1,"konto":"KONTO","kood":"__test3367","kuurs":1,"muud":null,"nimetus":"vfp test vara","projekt":null,"rasv":null,"rekvid":1,"sahharid":null,"status":0,"tegev":"TEGEV","tunnus":null,"uhik":null,"ulehind":0,"userid":1,"vailkaine":null,"valid":null,"valuuta":"EUR","vat":"20"}}',1,1)

*/

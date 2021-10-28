DROP FUNCTION IF EXISTS docs.sp_salvesta_arv(JSON, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION docs.sp_salvesta_arv(data JSON,
                                                user_id INTEGER,
                                                user_rekvid INTEGER)
    RETURNS INTEGER AS
$BODY$

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
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.sp_salvesta_arv(JSON, INTEGER, INTEGER) TO db;

/*
select docs.sp_salvesta_arv('{"id":0,"data": {"aa":"EE422200221027849353","aadress":null,"arvid":null,"asutus":null,"asutusid":29426,"bpm":null,"created":"02.02.2021 12:02:22","doc":"Arved","doc_status":0,"doc_type_id":"ARV","doklausid":null,"dokprop":"","id":0,"is_show_journal":0,"jaak":-75.0900,"journalid":null,"kbm":0.2000,"kbmkonto":"","kbmta":1,"kmkr":null,"konto":"","koostaja":null,"kpv":"20210202","lastupdate":"02.02.2021 12:02:22","laus_nr":null,"liik":0,"lisa":"","muud":null,"number":"95","objekt":null,"objektid":0,"operid":null,"regkood":null,"rekvid":null,"status":"Eelnõu","summa":1.2000,"tahtaeg":"20210216","tasud":null,"tasudok":null,"userid":3311,"viitenr":"","gridData":[{"formula":"","hind":1,"id":0,"kbm":0.2000,"kbmta":1,"km":"20","kogus":1,"konto":"323320","kood":"323320","kood1":"08102","kood2":"80","kood3":"","kood4":"","kood5":"3233","kuurs":0,"muud":"","nimetus":"","nomid":10056,"proj":"","soodus":0,"summa":1.2000,"tp":"","tunnus":"0810202","uhik":"","userid":0,"valuuta":"","vastisik":""}]}}'::json,
3311::integer,
125::integer) as id;



select * from ou.rekv where id = 125
select * from ou.userid where rekvid = 125 and kasutaja = 'vlad'

select * from docs.arv where parentid = 1616296
select * from docs.arv1 where parentid = 331

"gridData":[{"formula":"","hind":0,"id":0,"kbm":0,"kbmta":0,"km":"","kogus":0,"konto":"","kood":"","kood1":"","kood2":"","kood3":"","kood4":"","kood5":"","kuurs":0,"nimetus":"","nomid":0,"proj":"","soodus":0,"summa":0,"tp":"","tunnus":"","userid":0,"valuuta":"","vastisik":""}]
*/

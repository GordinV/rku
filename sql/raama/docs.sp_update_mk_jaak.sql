--DROP FUNCTION IF EXISTS docs.sp_update_arv_jaak(INTEGER);

CREATE OR REPLACE FUNCTION docs.sp_update_mk_jaak(l_mk_Id INTEGER)
    RETURNS NUMERIC AS
$BODY$
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
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.sp_update_mk_jaak(INTEGER) TO db;
/*

SELECT docs.sp_update_mk_jaak(parentid) from docs.mk
where rekvid = 69
*/


0810077579
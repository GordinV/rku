DROP FUNCTION IF EXISTS docs.update_last_rekl(INTEGER);

CREATE OR REPLACE FUNCTION docs.update_last_rekl(IN tnId INTEGER, OUT result INTEGER)
    -- проверка и вызов пересчета сальдо
AS
$BODY$
BEGIN
    raise notice 'tnId %', tnId;
    UPDATE docs.rekl SET last_shown = now() WHERE parentid = tnId;
    result = 1;
    RETURN;
END;
$BODY$
    LANGUAGE plpgsql
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION docs.update_last_rekl(INTEGER) TO db;

/*
SELECT docs.check_arv_jaak(null, 4711);

 */
-- FUNCTION: public.year(date)

DROP FUNCTION IF EXISTS public.year(DATE);

CREATE OR REPLACE FUNCTION public.year(
    DATE DEFAULT current_date)
    RETURNS INTEGER
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS
$BODY$
BEGIN
    RETURN cast(extract(YEAR FROM $1) AS INT);
END;
$BODY$;
GRANT EXECUTE ON FUNCTION year(DATE) TO db;


--select year('2020-01-01')
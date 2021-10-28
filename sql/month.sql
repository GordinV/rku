-- FUNCTION: public.month(date)

-- DROP FUNCTION public.month(date);

CREATE OR REPLACE FUNCTION public.month(
    DATE DEFAULT current_date)
    RETURNS INTEGER
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS
$BODY$
BEGIN
    RETURN cast(extract(MONTH FROM $1) AS INT8);
END;
$BODY$;

GRANT EXECUTE ON FUNCTION month(DATE) TO db;

--select month()
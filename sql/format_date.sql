-- FUNCTION: public.format_date(text)

-- DROP FUNCTION IF EXISTS public.format_date(text);

CREATE OR REPLACE FUNCTION public.format_date(
    l_kpv text)
    RETURNS date
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$


DECLARE
    return_date DATE;
BEGIN
    -- format DD.MM.YYYY HH:MI:SS
    IF (SELECT l_kpv SIMILAR TO '__.__.____') or (SELECT l_kpv SIMILAR TO '__.__.____ __:__*')
    THEN
        return_date = make_date(substring(l_kpv FROM 7 FOR 4)::INTEGER, substring(l_kpv FROM 4 FOR 2)::INTEGER,
                                left(l_kpv, 2)::INTEGER);

    ELSEIF (isfinite(l_kpv::DATE))
    THEN
        return_date = l_kpv;
    END IF;

    RETURN return_date;

EXCEPTION
    WHEN OTHERS
        THEN
            RAISE NOTICE 'error % %', SQLERRM, SQLSTATE;
            RETURN NULL;

END;
$BODY$;

ALTER FUNCTION public.format_date(text)
    OWNER TO postgres;

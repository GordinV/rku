-- FUNCTION: public.empty(character varying)

-- DROP FUNCTION public.empty(character varying);

CREATE OR REPLACE FUNCTION public.empty(
    CHARACTER VARYING)
    RETURNS BOOLEAN
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS
$BODY$

BEGIN

    IF $1 IS NULL OR length(ltrim(rtrim($1))) < 1
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$BODY$;

GRANT EXECUTE ON FUNCTION public.empty(CHARACTER VARYING) TO db;


-- FUNCTION: public.empty(date)

-- DROP FUNCTION public.empty(date);

CREATE OR REPLACE FUNCTION public.empty(
    DATE)
    RETURNS BOOLEAN
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS
$BODY$

BEGIN

    IF $1 IS NULL OR year($1) < year(now()::DATE) - 100
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$BODY$;


GRANT EXECUTE ON FUNCTION public.empty(DATE) TO db;


-- FUNCTION: public.empty(integer)

-- DROP FUNCTION public.empty(integer);

CREATE OR REPLACE FUNCTION public.empty(
    INTEGER)
    RETURNS BOOLEAN
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS
$BODY$

BEGIN

    IF $1 IS NULL OR $1 = 0
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$BODY$;

GRANT EXECUTE ON FUNCTION public.empty(INTEGER) TO db;

-- FUNCTION: public.empty(numeric)

-- DROP FUNCTION public.empty(numeric);

CREATE OR REPLACE FUNCTION public.empty(
    NUMERIC)
    RETURNS BOOLEAN
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS
$BODY$

BEGIN

    IF $1 IS NULL OR $1 = 0
    THEN

        RETURN TRUE;

    ELSE

        RETURN FALSE;

    END IF;

END;

$BODY$;

GRANT EXECUTE ON FUNCTION public.empty(NUMERIC) TO db;





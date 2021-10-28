-- FUNCTION: docs.create_number_sequence(integer, text, boolean)

-- DROP FUNCTION docs.create_number_sequence(integer, text, boolean);

CREATE OR REPLACE FUNCTION docs.create_number_sequence(l_rekvid INTEGER,
                                                       l_dok TEXT,
                                                       l_found_last_num BOOLEAN DEFAULT TRUE)
    RETURNS TEXT
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS
$BODY$
DECLARE
    l_sequence_name TEXT = lower(l_dok) || '_' || l_rekvid::TEXT || '_number';
    l_sql           TEXT;
    l_number        TEXT;
    l_result        INTEGER;
    l_last_id       INTEGER;
BEGIN
    -- sequence name
    -- check if exists sequencetbl
    IF NOT EXISTS(
            SELECT 1 FROM pg_class WHERE relname = l_sequence_name
        )
    THEN
        -- IF NOT then sql for create sequence

        -- get last doc number
        IF l_found_last_num
        THEN

            l_sql = 'select (max(SUBSTRING(''0'' || coalesce(tbl.number,''0''), ' || quote_literal('Y*[0-9]\d+') ||
                    ')::bigint) ::bigint) from docs.' || l_dok || ' tbl where rekvid = $1 ' ||
                    CASE WHEN l_dok = 'ARV' THEN ' and liik = 0' ELSE '' END;
            EXECUTE l_sql INTO l_number USING l_rekvid;

            IF length(l_number) > 6
            THEN
                l_number = '1';
            END IF;
        ELSE
            l_number = '1';
        END IF;

        l_sql = 'CREATE SEQUENCE ' || l_sequence_name || ' AS integer;' ||
                'GRANT ALL ON SEQUENCE ' || l_sequence_name || ' TO public;';

        IF l_number IS NOT NULL AND l_number::INTEGER > 0
        THEN
            -- will store last value
            l_sql = l_sql || 'select setval(' || quote_literal(l_sequence_name) || ',' || l_number || ');';

        END IF;

        -- execute sequnce
        EXECUTE l_sql;
    ELSE
        l_sql = 'GRANT ALL ON SEQUENCE ' || l_sequence_name || ' TO public;';

        IF l_number IS NOT NULL AND l_number::INTEGER > 0
        THEN
            -- will store last value
            l_sql = l_sql || 'select setval(' || quote_literal(l_sequence_name) || ',0);';

        END IF;

        -- execute sequnce
        EXECUTE l_sql;
    END IF;

    -- return name of sequence

    RETURN l_sequence_name;
END;
$BODY$;


GRANT EXECUTE ON FUNCTION docs.create_number_sequence(INTEGER, TEXT, BOOLEAN) TO db;

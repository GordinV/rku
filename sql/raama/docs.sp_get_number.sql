﻿DROP FUNCTION IF EXISTS sp_get_number(tnrekvid INTEGER, tcdok TEXT, tnyear INTEGER, tndokpropid INTEGER);
DROP FUNCTION IF EXISTS docs.sp_get_number(tnrekvid INTEGER, tcdok TEXT, tnyear INTEGER, tndokpropid INTEGER);

CREATE FUNCTION docs.sp_get_number(l_rekvid INTEGER, l_dok TEXT, l_year INTEGER, l_dokpropid INTEGER)
    RETURNS TEXT
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_number          RECORD;
    lcPref            TEXT = '%';
    lcNumber          TEXT = '0';
    lcTableName       TEXT;
    lcAdditionalWhere TEXT = '';
    lcSqlString       TEXT;
    l_seq_name        TEXT;
BEGIN

    IF l_dokpropid IS NOT NULL
    THEN
        SELECT ltrim(rtrim(proc_)) INTO lcPref
        FROM libs.dokprop
        WHERE id = l_dokpropid;
    END IF;

    lcPref = coalesce(lcPref, '%');

    CASE
        WHEN l_dok = 'ARV'
            THEN
                lcTableName = 'docs.arv';
                lcAdditionalWhere = ' and liik = 0 ';

                l_seq_name = docs.create_number_sequence(l_rekvid, l_dok);
                SELECT nextval(l_seq_name) AS number INTO v_number;
        WHEN l_dok = 'TEATIS'
            THEN
                l_seq_name = docs.create_number_sequence(l_rekvid, l_dok, false);
                SELECT nextval(l_seq_name) AS number INTO v_number;
        WHEN l_dok = 'SARV'
            THEN
                lcTableName = 'docs.arv';
                lcAdditionalWhere = ' and liik = 1 and operid is not null and not empty(operid)';
        WHEN l_dok = 'SORDER'
            THEN
                lcTableName = 'docs.korder1';
                lcAdditionalWhere = ' and tyyp = 1 ';
        WHEN l_dok = 'VORDER'
            THEN
                lcTableName = 'docs.korder1';
                lcAdditionalWhere = ' and tyyp = 2 ';
        WHEN l_dok = 'MK'
            THEN
                lcTableName = 'docs.mk';
                lcAdditionalWhere = ' and OPT = 1 ';
        WHEN l_dok = 'SMK'
            THEN
                lcTableName = 'docs.mk';
                lcAdditionalWhere = ' and OPT = 1 ';
                l_seq_name = docs.create_number_sequence(l_rekvid, l_dok, FALSE);
                SELECT nextval(l_seq_name) AS number INTO v_number;
        WHEN l_dok = 'VMK'
            THEN
                lcTableName = 'docs.mk';
                lcAdditionalWhere = ' and OPT = 2 ';
        WHEN l_dok = 'LEPING'
            THEN
                lcTableName = 'docs.leping1';
        WHEN l_dok = 'TAOTLUS'
            THEN
                lcTableName = 'eelarve.taotlus';
        WHEN l_dok = 'LUBA'
            THEN
                lcTableName =
                        '(select left(l.number,2)::text as number, l.parentid, l.rekvid, l.algkpv as kpv from rekl.luba l)';
        END CASE;

    IF l_dok NOT IN ('ARV', 'SMK', 'TEATIS')
    THEN
        -- building sql query with regexp for only numbers
        lcSqlString = 'select (max(SUBSTRING(''0'' || coalesce(tbl.number,''0''), ' || quote_literal('Y*[0-9]\d+') ||
                      ')::bigint) ::bigint) as number from docs.doc d inner join '
            || lcTableName || ' tbl on d.id = tbl.parentid and d.status <> 3 '
            ||
                      ' where tbl.rekvId = $1::integer and year(tbl.kpv) = $2::integer and encode(tbl.number::bytea, ''escape'')::text  ilike $3::text';

        lcSqlString = lcSqlString || lcAdditionalWhere;
        EXECUTE lcSqlString
            INTO v_number
            USING l_rekvid, l_year, lcPref;
    END IF;

    -- will plus pref and encrement

    IF lcPref = '%'
    THEN
        lcPref = '';
    END IF;

    lcNumber = lcPref || (coalesce(v_number.number, 0) + 1) :: TEXT;

    RETURN lcNumber;
END;
$$;

GRANT EXECUTE ON FUNCTION docs.sp_get_number(INTEGER, TEXT, INTEGER, INTEGER) TO db;


/*
select docs.sp_get_number(118, 'SMK', 2020, null)

SELECT 1 FROM pg_class WHERE relname = 'smk_128_number'

select
CREATE SEQUENCE smk_128_number AS integer;
GRANT ALL ON SEQUENCE smk_128_number TO public;
select setval('smk_128_number',1)
 */
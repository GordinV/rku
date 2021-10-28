DROP FUNCTION IF EXISTS ou.get_user_data(l_kasutaja TEXT, l_rekvid INTEGER, l_module TEXT);

CREATE OR REPLACE FUNCTION ou.get_user_data(l_kasutaja TEXT, l_rekvid INTEGER, l_module TEXT default 'lapsed')
    RETURNS TABLE (
        id             INTEGER,
        rekvid         INTEGER,
        kasutaja       TEXT,
        ametnik        TEXT,
        parool         TEXT,
        muud           TEXT,
        last_login     TIMESTAMP,
        asutus         TEXT,
        asutus_tais    TEXT,
        regkood        TEXT,
        aadress        TEXT,
        tel            TEXT,
        email          TEXT,
        allowed_access TEXT[],
        allowed_libs   TEXT[],
        parentid       INTEGER,
        parent_asutus  TEXT,
        roles          JSONB
    ) AS
$BODY$

SELECT u.id,
       u.rekvid,
       u.kasutaja::TEXT,
       u.ametnik::TEXT,
       u.parool::TEXT,
       u.muud,
       u.last_login,
       r.nimetus::TEXT                                                    AS asutus,
       CASE WHEN r.muud IS NOT NULL THEN r.muud ELSE r.nimetus END ::TEXT AS asutus_tais,
       r.regkood::TEXT                                                    AS regkood,
       r.aadress::TEXT                                                    AS aadress,
       r.tel::TEXT                                                        AS tel,
       r.email::TEXT                                                      AS email,
       rs.a::TEXT[]                                                       AS allowed_access,
       allowed_modules.libs::TEXT[]                                       AS allowed_libs,
       r.parentid,
       CASE
           WHEN parent_r.muud IS NOT NULL THEN parent_r.muud
           ELSE
               coalesce(parent_r.nimetus, CASE WHEN r.muud IS NOT NULL THEN r.muud ELSE r.nimetus END)
           END ::TEXT                                                     AS parent_asutus,
       u.roles

FROM ou.userid u
         JOIN ou.rekv r ON r.id = u.rekvid AND rtrim(ltrim(u.kasutaja))::TEXT = ltrim(rtrim(l_kasutaja)) and parentid < 999
         LEFT OUTER JOIN ou.rekv parent_r ON parent_r.id = r.parentid
         JOIN (
    SELECT array_agg('{"id":'::TEXT || r.id::TEXT || ',"nimetus":"'::TEXT || r.nimetus || '"}') AS a
    FROM (
             SELECT r.id, r.nimetus
             FROM ou.rekv r
                      JOIN ou.userid u_1 ON u_1.rekvid = r.id
             WHERE ltrim(rtrim(u_1.kasutaja))::TEXT = ltrim(rtrim(l_kasutaja))
               AND r.status <> 3
               AND u_1.status <> 3
         ) r) rs ON rs.a IS NOT NULL
         JOIN (
    SELECT array_agg('{"id":'::TEXT || lib.id::TEXT || ',"nimetus":"'::TEXT || lib.nimetus || '"}')
               AS libs
    FROM (
             SELECT id,
                    kood::TEXT,
                    nimetus::TEXT,
                    library::TEXT                          AS lib,
                    (properties::JSONB -> 'module')::JSONB AS module,
                    (properties::JSONB -> 'roles')::JSONB  AS roles
             FROM libs.library l
             WHERE l.library = 'DOK'
               AND status <> 3
               AND ((properties::JSONB -> 'module') @> l_module::JSONB OR l_module IS NULL)
         ) lib
) allowed_modules ON allowed_modules.libs IS NOT NULL
WHERE (r.id = l_rekvid OR l_rekvid IS NULL)
ORDER BY u.last_login DESC
LIMIT 1;

$BODY$
    LANGUAGE SQL
    VOLATILE
    COST 100;

GRANT EXECUTE ON FUNCTION ou.get_user_data(l_kasutaja TEXT, l_rekvid INTEGER, l_module TEXT) TO db;



/*

SELECT *
FROM ou.get_user_data('raama', null, null)

*/

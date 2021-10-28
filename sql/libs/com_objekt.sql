DROP VIEW IF EXISTS com_objekt;

CREATE VIEW com_objekt AS
SELECT qry.id,
       qry.kood,
       qry.nimetus,
       qry.rekvid,
       qry.asutus_id
FROM (SELECT 0                         AS id,
             ''::CHARACTER VARYING(20) AS kood,
             ''::CHARACTER VARYING(20) AS nimetus,
             0::INTEGER                AS rekvid,
             NULL::INTEGER             AS asutus_id
      UNION
      SELECT o.id,
             ''        AS kood,
             o.aadress AS nimetus,
             o.rekvid,
             oo.asutus_id
      FROM libs.object o
               INNER JOIN libs.object_owner oo
                          ON o.id = oo.object_id
      WHERE o.status <> 3) qry
ORDER BY qry.kood;

GRANT INSERT, SELECT, UPDATE, DELETE, REFERENCES, TRIGGER ON TABLE com_objekt TO db;

DROP VIEW IF EXISTS com_nomenclature;

CREATE OR REPLACE VIEW com_nomenclature AS

SELECT *
FROM (SELECT 0                    AS id,
             NULL :: INTEGER      AS rekvid,
             '' :: VARCHAR(20)    AS kood,
             '' :: VARCHAR(20)    AS nimetus,
             'DOK' :: VARCHAR(20) AS DOK,
             0 :: VARCHAR(10)     AS vat,
             0 :: NUMERIC(14, 2)  AS hind,
             'muud':: TEXT        AS uhik,
             0 :: NUMERIC(14, 4)  AS kogus,
             '' :: VARCHAR(20)    AS konto,
             '' :: TEXT           AS formula,
             NULL::DATE           AS valid
      UNION
      SELECT n.id,
             n.rekvid,
             trim(n.kood)::VARCHAR(20)                                        AS kood,
             trim(n.nimetus)::VARCHAR(254)                                    AS nimetus,
             trim(n.dok)::VARCHAR(20)                                         AS dok,
             (n.properties :: JSONB ->> 'vat') :: VARCHAR(10)                 AS vat,
             n.hind                                                           AS hind,
             n.uhik::TEXT                                                     AS uhik,
             n.kogus                                                          AS kogus,
             coalesce((n.properties :: JSONB ->> 'konto') :: VARCHAR(20), '') AS konto,
             coalesce((n.properties :: JSONB ->> 'formula') :: TEXT, '')      AS formula,
             (n.properties::JSONB ->> 'valid')::DATE                          AS valid
      FROM libs.nomenklatuur n
      WHERE n.status <> 3
     ) qry
ORDER BY kood;

GRANT SELECT ON TABLE com_nomenclature TO db;


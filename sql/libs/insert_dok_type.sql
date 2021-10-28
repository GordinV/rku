INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'TEATIS'                                                    AS kood,
       'Teatised'                                                  AS nimetus,
       'DOK'                                                       AS library,
       '{"type":"library", "module":["juht","raama", "kasutaja"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'TEATIS');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'REKL'                                                    AS kood,
       'Reklaam'                                                  AS nimetus,
       'DOK'                                                       AS library,
       '{"type":"document", "module":["juht"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'REKL');


INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'TAOTLUS_LOGIN'                          AS kood,
       'Registreerimise taotlused'              AS nimetus,
       'DOK'                                    AS library,
       '{"type":"library", "module":["admin"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'TAOTLUS_LOGIN');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'SORDER'                                                AS kood,
       'Sissemakse kassaorder'                             AS nimetus,
       'DOK'                                                AS library,
       '{"type":"document", "module":["raama"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'SORDER');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'VORDER'                                                AS kood,
       'Väljamakse kassaorder'                             AS nimetus,
       'DOK'                                                AS library,
       '{"type":"document", "module":["raama"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'VORDER');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'SMK'                                                AS kood,
       'Sissemakse korraldused'                             AS nimetus,
       'DOK'                                                AS library,
       '{"type":"document", "module":["raama","kasutaja"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'SMK');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'VMK'                                                AS kood,
       'Väljamakse korraldused'                             AS nimetus,
       'DOK'                                                AS library,
       '{"type":"document", "module":["raama","kasutaja"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'VMK');


INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'ARV'                                                AS kood,
       'Arved'                                              AS nimetus,
       'DOK'                                                AS library,
       '{"type":"document", "module":["raama","kasutaja"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'ARV');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'LEPING'                                                    AS kood,
       'Lepingud'                                                  AS nimetus,
       'DOK'                                                       AS library,
       '{"type":"document", "module":["kasutaja","raama","juht"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'LEPING');


INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'ANDMED'                                                    AS kood,
       'Mõõdukiri andmed'                                          AS nimetus,
       'DOK'                                                       AS library,
       '{"type":"document", "module":["kasutaja","raama","juht"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'ANDMED');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'REKV'                                           AS kood,
       'Oma asutuse andmed'                             AS nimetus,
       'DOK'                                            AS library,
       '{"type":"settings", "module":["juht","raama"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'REKV');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'CONFIG'                                  AS kood,
       'Konfiguratsioon'                         AS nimetus,
       'DOK'                                     AS library,
       '{"type":"settings", "module":["admin"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'CONFIG');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'USERID'                                  AS kood,
       'Kasutaja andmed'                         AS nimetus,
       'DOK'                                     AS library,
       '{"type":"settings", "module":["admin"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'USERID');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'KAIVE_ARUANNE'                      AS kood,
       'Käibearuanne'                      AS nimetus,
       'DOK'                                    AS library,
       '{"type":"aruanne", "module":["raama"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'KAIVE_ARUANNE');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'OBJEKT'                                                   AS kood,
       'Objektid'                                                 AS nimetus,
       'DOK'                                                      AS library,
       '{"type":"library", "module":["raama","juht","kasutaja"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'OBJEKT');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'ASUTUSED'                                      AS kood,
       'Kliendid'                                      AS nimetus,
       'DOK'                                           AS library,
       '{"type":"library", "module":["raama","juht"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'ASUTUSED');

INSERT INTO libs.library (rekvid, kood, nimetus, library, properties)
SELECT 1::INTEGER,
       'NOMENCLATURE'                                  AS kood,
       'Teenused'                                      AS nimetus,
       'DOK'                                           AS library,
       '{"type":"library", "module":["raama","juht"]}' AS properties
WHERE NOT exists(SELECT id FROM libs.library WHERE library = 'DOK' AND kood = 'NOMENCLATURE');

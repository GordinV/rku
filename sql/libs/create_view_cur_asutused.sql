drop view if exists cur_asutused;

CREATE VIEW cur_asutused AS
SELECT
  a.id,
  a.regkood,
  a.nimetus,
  a.omvorm,
  a.aadress,
  a.tp,
  coalesce(a.email,'')::varchar(254) as email,
  a.mark,
  coalesce((a.properties ->> 'kehtivus' :: TEXT)::date,current_date + INTERVAL '10 years') :: DATE AS kehtivus,
  a.staatus
FROM libs.asutus a
WHERE (a.staatus <> 3);


GRANT SELECT on cur_asutused to db;

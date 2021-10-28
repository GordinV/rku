DROP TABLE if exists libs.asutus;

CREATE TABLE libs.asutus
(
    id serial,
    rekvid integer,
    kasutaja text,
    regkood character(20) NOT NULL,
    nimetus character(254) NOT NULL,
    omvorm character(20),
    aadress text,
    kontakt text,
    tel character(60),
    faks character(60),
    email character(60),
    muud text,
    tp character varying(20) NOT NULL,
    staatus integer DEFAULT 1,
    mark text,
    properties jsonb,
    ajalugi jsonb,
    CONSTRAINT asutus_pkey PRIMARY KEY (id)
)
    WITH (
        OIDS=FALSE
    );

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE libs.asutus TO db;
GRANT INSERT, SELECT, UPDATE, DELETE, REFERENCES, TRIGGER ON TABLE libs.asutus TO db;


CREATE INDEX asutus_kasutaja
    ON libs.asutus
        USING btree
        (kasutaja COLLATE pg_catalog."default", omvorm COLLATE pg_catalog."default")
    where staatus <> 3;


-- Index: libs.asutus_nimetus

-- DROP INDEX libs.asutus_nimetus;

CREATE INDEX asutus_nimetus
    ON libs.asutus
        USING btree
        (nimetus COLLATE pg_catalog."default", omvorm COLLATE pg_catalog."default")
    where staatus <> 3;

-- Index: libs.kood_asutus

-- DROP INDEX libs.kood_asutus;

CREATE INDEX kood_asutus
    ON libs.asutus
        USING btree
        (regkood COLLATE pg_catalog."default")
    where staatus <> 3;



CREATE INDEX asutus_staatus
    ON libs.asutus (staatus)
    where staatus <> 3;

GRANT ALL ON SEQUENCE libs.asutus_id_seq TO db;

ALTER TABLE libs.asutus add COLUMN  kasutaja text;
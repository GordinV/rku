
-- DROP TABLE ou.rekv;

CREATE TABLE ou.rekv
(
    id serial,
    parentid integer,
    regkood character(20) NOT NULL,
    nimetus text NOT NULL,
    kbmkood character(20) null,
    aadress text null,
    haldus text null,
    tel text null,
    faks text null,
    email text null,
    juht text null,
    raama text null,
    muud text null,
    properties jsonb,
    ajalugu jsonb,
    status integer DEFAULT 1,
    CONSTRAINT rekv_pkey PRIMARY KEY (id)
)
    WITH (
        OIDS = false
    )
    TABLESPACE pg_default;

ALTER TABLE ou.rekv
    OWNER to postgres;

GRANT ALL ON TABLE ou.rekv TO db;


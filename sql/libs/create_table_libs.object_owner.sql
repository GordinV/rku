DROP TABLE if exists libs.object_owner;

CREATE TABLE libs.object_owner
(
    id serial,
    object_id integer,
    asutus_id INTEGER,
    properties jsonb,
    CONSTRAINT object_owner_pkey PRIMARY KEY (id)
)
    WITH (
        OIDS=FALSE
    );

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE libs.object_owner TO db;


CREATE INDEX object_owner_asutus_id
    ON libs.object_owner
        USING btree
(object_id, asutus_id);

GRANT ALL ON SEQUENCE libs.object_owner_id_seq TO db;


DROP TABLE if exists libs.asutus_user_id;

CREATE TABLE libs.asutus_user_id
(
    id serial,
    user_id integer,
    asutus_id INTEGER,
    properties jsonb,
    CONSTRAINT asutus_user_id_pkey PRIMARY KEY (id)
)
    WITH (
        OIDS=FALSE
    );

GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE libs.asutus_user_id TO db;


CREATE INDEX asutus_user_id_idx
    ON libs.asutus_user_id
        USING btree
        (user_id, asutus_id);

GRANT ALL ON SEQUENCE libs.asutus_user_id_id_seq TO db;


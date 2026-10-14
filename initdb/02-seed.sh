#!/bin/sh
# Runs once, when the database volume is first created.
# Replaces the default guacadmin login with ADMIN_EMAIL (signed in through the gate)
# and adds a VNC connection to the Mac running Docker.
set -eu
: "${ADMIN_EMAIL:?set ADMIN_EMAIL in .env}"

psql -v ON_ERROR_STOP=1 -v email="$ADMIN_EMAIL" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
-- Runs once, on first start of the database, after 01-schema.sql.

-- The stock schema ships a guacadmin/guacadmin account; remove it.
DELETE FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER';

-- The one account. Sign-in is by Google (header from oauth2-proxy), so the
-- password is random and never used.
INSERT INTO guacamole_entity (name, type) VALUES (:'email', 'USER');

INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date)
SELECT entity_id,
       sha256(gen_random_uuid()::text::bytea),
       sha256(gen_random_uuid()::text::bytea),
       now()
FROM guacamole_entity
WHERE name = :'email' AND type = 'USER';

INSERT INTO guacamole_system_permission (entity_id, permission)
SELECT entity_id, p.permission::guacamole_system_permission_type
FROM guacamole_entity,
     (VALUES ('ADMINISTER'), ('CREATE_CONNECTION'), ('CREATE_CONNECTION_GROUP'),
             ('CREATE_SHARING_PROFILE'), ('CREATE_USER'), ('CREATE_USER_GROUP')) AS p (permission)
WHERE name = :'email' AND type = 'USER';

-- This Mac, over macOS Screen Sharing. No username/password stored here:
-- Guacamole prompts for the Mac login each time.
INSERT INTO guacamole_connection (connection_name, protocol) VALUES ('This Mac', 'vnc');

INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
SELECT connection_id, p.name, p.value
FROM guacamole_connection,
     (VALUES ('hostname', 'host.docker.internal'), ('port', '5900')) AS p (name, value)
WHERE connection_name = 'This Mac';

INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
SELECT e.entity_id, c.connection_id, p.permission::guacamole_object_permission_type
FROM guacamole_entity e, guacamole_connection c,
     (VALUES ('READ'), ('UPDATE'), ('DELETE'), ('ADMINISTER')) AS p (permission)
WHERE e.name = :'email' AND e.type = 'USER' AND c.connection_name = 'This Mac';
SQL

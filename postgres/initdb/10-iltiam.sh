#!/bin/sh
# Roles and databases of one environment (Runbook 5, issue #2). The postgres image runs this once, on the first start
# with an empty data directory, as the superuser over the local socket. Changing it later changes nothing: a
# password change goes through docs/secrets.md, section 6.3.
#
#   role iltiam     owns database iltiam     (the backend; password BACKEND_DB_PASSWORD)
#   role iltiam_ai  owns database iltiam_ai  (the AI service; password AI_DB_PASSWORD)
#
# Neither role can connect to the other's database. The passwords reach psql on stdin, never as arguments.
# The image may source this file instead of running it, so it sets no shell options and never calls exit.

: "${BACKEND_DB_PASSWORD:?BACKEND_DB_PASSWORD is not set for the postgres container}"
: "${AI_DB_PASSWORD:?AI_DB_PASSWORD is not set for the postgres container}"

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER:-postgres}" --dbname "${POSTGRES_DB:-postgres}" <<EOSQL
CREATE ROLE iltiam LOGIN PASSWORD '${BACKEND_DB_PASSWORD}';
CREATE ROLE iltiam_ai LOGIN PASSWORD '${AI_DB_PASSWORD}';
CREATE DATABASE iltiam OWNER iltiam;
CREATE DATABASE iltiam_ai OWNER iltiam_ai;
REVOKE ALL ON DATABASE iltiam FROM PUBLIC;
REVOKE ALL ON DATABASE iltiam_ai FROM PUBLIC;
EOSQL

\set ON_ERROR_STOP on

SELECT 'CREATE DATABASE vehicle_insurance'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_database WHERE datname = 'vehicle_insurance'
)
\gexec

REVOKE ALL ON DATABASE vehicle_insurance FROM PUBLIC;
GRANT CONNECT ON DATABASE vehicle_insurance TO PUBLIC;


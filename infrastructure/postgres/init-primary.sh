#!/usr/bin/env bash
set -Eeuo pipefail

required=(
  POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
  REPLICATION_PASSWORD REPMGR_PASSWORD
  HEALTHCHECK_PASSWORD BACKUP_PASSWORD
  APP_AGENT_PASSWORD APP_ADJUSTER_PASSWORD APP_AUDITOR_PASSWORD
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "[init-primary] missing environment variable: ${name}" >&2
    exit 1
  fi
done

psql=(psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1)

"${psql[@]}" \
  --set replication_password="$REPLICATION_PASSWORD" \
  --set repmgr_password="$REPMGR_PASSWORD" \
  --set healthcheck_password="$HEALTHCHECK_PASSWORD" \
  --set backup_password="$BACKUP_PASSWORD" \
  --set agent_password="$APP_AGENT_PASSWORD" \
  --set adjuster_password="$APP_ADJUSTER_PASSWORD" \
  --set auditor_password="$APP_AUDITOR_PASSWORD" <<'SQL'
SET password_encryption = 'scram-sha-256';

CREATE ROLE replicator LOGIN REPLICATION PASSWORD :'replication_password';
CREATE ROLE repmgr LOGIN REPLICATION PASSWORD :'repmgr_password';
CREATE ROLE healthcheck_user LOGIN PASSWORD :'healthcheck_password';
CREATE ROLE backup_operator LOGIN PASSWORD :'backup_password';

CREATE ROLE app_agent_anna LOGIN PASSWORD :'agent_password';
CREATE ROLE app_adjuster_piotr LOGIN PASSWORD :'adjuster_password';
CREATE ROLE app_auditor_ewa LOGIN PASSWORD :'auditor_password';

GRANT pg_monitor TO healthcheck_user;
GRANT pg_monitor TO repmgr;
GRANT CONNECT ON DATABASE vehicle_insurance TO healthcheck_user, backup_operator;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_promote(boolean, integer) TO repmgr;
SQL

"${psql[@]}" --file /opt/project/database/migrations/001_schema.sql
"${psql[@]}" --file /opt/project/database/roles/001_roles_and_grants.sql

"${psql[@]}" <<'SQL'
GRANT grp_agent TO app_agent_anna;
GRANT grp_claims_adjuster TO app_adjuster_piotr;
GRANT grp_auditor TO app_auditor_ewa;

GRANT USAGE ON SCHEMA insurance, claims, audit TO backup_operator;
GRANT SELECT ON ALL TABLES IN SCHEMA insurance, claims, audit TO backup_operator;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA insurance, claims, audit TO backup_operator;
ALTER DEFAULT PRIVILEGES IN SCHEMA insurance GRANT SELECT ON TABLES TO backup_operator;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT SELECT ON TABLES TO backup_operator;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT ON TABLES TO backup_operator;
SQL

"${psql[@]}" --file /opt/project/database/seed/001_demo_data.sql

if ! psql --username "$POSTGRES_USER" --dbname postgres --tuples-only --command \
  "SELECT 1 FROM pg_database WHERE datname = 'repmgr'" | grep -q 1; then
  createdb --username "$POSTGRES_USER" --owner repmgr repmgr
fi

echo "[init-primary] database, roles and seed initialized"

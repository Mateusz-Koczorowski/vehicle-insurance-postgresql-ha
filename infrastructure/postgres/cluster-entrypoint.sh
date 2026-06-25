#!/usr/bin/env bash
set -Eeuo pipefail

: "${NODE_ROLE:?NODE_ROLE must be primary or standby}"
: "${NODE_ID:?NODE_ID is required}"
: "${NODE_NAME:?NODE_NAME is required}"
: "${NODE_HOST:?NODE_HOST is required}"
: "${REPMGR_PASSWORD:?REPMGR_PASSWORD is required}"

export PGDATA="${PGDATA:-/var/lib/postgresql/18/docker}"
config_file=/etc/postgresql/project-postgresql.conf
hba_file=/etc/postgresql/project-pg_hba.conf
repmgr_config=/run/repmgr/repmgr.conf

write_repmgr_config() {
  mkdir -p /run/repmgr
  cat >"$repmgr_config" <<EOF
node_id=${NODE_ID}
node_name='${NODE_NAME}'
conninfo='host=${NODE_HOST} user=repmgr dbname=repmgr password=${REPMGR_PASSWORD} connect_timeout=2'
data_directory='${PGDATA}'
use_replication_slots=yes
replication_user='replicator'
log_level='NOTICE'
EOF
  chown -R postgres:postgres /run/repmgr
  chmod 0600 "$repmgr_config"
}

wait_for_postgres() {
  local host=$1
  local attempts=60
  until pg_isready -h "$host" -p 5432 -d "${POSTGRES_DB}" >/dev/null 2>&1; do
    attempts=$((attempts - 1))
    if [[ $attempts -le 0 ]]; then
      echo "[cluster-entrypoint] PostgreSQL at ${host}:5432 did not become ready" >&2
      return 1
    fi
    sleep 2
  done
}

register_node() {
  export PGPASSWORD="$REPMGR_PASSWORD"
  if [[ "$NODE_ROLE" == "primary" ]]; then
    gosu postgres repmgr -f "$repmgr_config" primary register --force
  else
    gosu postgres repmgr -f "$repmgr_config" standby register --force
  fi
}

terminate_postgres() {
  if [[ -n "${postgres_pid:-}" ]] && kill -0 "$postgres_pid" 2>/dev/null; then
    kill -TERM "$postgres_pid"
    wait "$postgres_pid"
  fi
}

write_repmgr_config

if [[ "$NODE_ROLE" == "primary" ]]; then
  docker-entrypoint.sh postgres \
    -c "config_file=${config_file}" \
    -c "hba_file=${hba_file}" &
  postgres_pid=$!
  trap terminate_postgres TERM INT
  wait_for_postgres 127.0.0.1
  register_node
  wait "$postgres_pid"
  exit $?
fi

: "${PRIMARY_HOST:?PRIMARY_HOST is required for standby}"
: "${REPLICATION_PASSWORD:?REPLICATION_PASSWORD is required for standby}"
: "${REPLICATION_SLOT:?REPLICATION_SLOT is required for standby}"

mkdir -p "$PGDATA"
chown -R postgres:postgres "$(dirname "$PGDATA")"

if [[ ! -s "$PGDATA/PG_VERSION" ]]; then
  wait_for_postgres "$PRIMARY_HOST"
  echo "[cluster-entrypoint] cloning ${NODE_NAME} from ${PRIMARY_HOST}"
  find "$PGDATA" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  export PGPASSWORD="$REPLICATION_PASSWORD"
  gosu postgres pg_basebackup \
    --host="$PRIMARY_HOST" \
    --port=5432 \
    --username=replicator \
    --pgdata="$PGDATA" \
    --wal-method=stream \
    --write-recovery-conf \
    --create-slot \
    --slot="$REPLICATION_SLOT" \
    --checkpoint=fast \
    --progress
fi

gosu postgres postgres \
  -D "$PGDATA" \
  -c "config_file=${config_file}" \
  -c "hba_file=${hba_file}" &
postgres_pid=$!
trap terminate_postgres TERM INT
wait_for_postgres 127.0.0.1
register_node
wait "$postgres_pid"

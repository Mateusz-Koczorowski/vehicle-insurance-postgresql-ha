#!/usr/bin/env bash
set -Eeuo pipefail

required=(
  HEALTHCHECK_PASSWORD
  APP_AGENT_PASSWORD APP_ADJUSTER_PASSWORD APP_AUDITOR_PASSWORD
  BACKUP_PASSWORD
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "[pgpool] missing environment variable: ${name}" >&2
    exit 1
  fi
done

install -m 0600 /etc/pgpool2/pgpool.conf.template /tmp/pgpool.conf
sed -i \
  -e "s|@HEALTHCHECK_PASSWORD@|${HEALTHCHECK_PASSWORD//|/\\|}|g" \
  /tmp/pgpool.conf

cat >/tmp/pool_passwd <<EOF
healthcheck_user:TEXT${HEALTHCHECK_PASSWORD}
app_agent_anna:TEXT${APP_AGENT_PASSWORD}
app_adjuster_piotr:TEXT${APP_ADJUSTER_PASSWORD}
app_auditor_ewa:TEXT${APP_AUDITOR_PASSWORD}
backup_operator:TEXT${BACKUP_PASSWORD}
EOF
chmod 0600 /tmp/pool_passwd

exec pgpool -n -f /tmp/pgpool.conf -a /etc/pgpool2/pool_hba.conf

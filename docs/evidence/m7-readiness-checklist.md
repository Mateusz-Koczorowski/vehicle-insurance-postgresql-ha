# M7 readiness checklist

Date: 2026-06-27

This checklist captures the final integration rehearsal before the classroom
demo. The destructive failover path is prepared as a demo step, but was not run
against the main stack during this rehearsal so the classroom environment stays
ready.

## Current status

- Main stack `vehicle-insurance-ha`: running and healthy.
- Application URL: `http://127.0.0.1:8000`.
- PgPool SQL endpoint: `127.0.0.1:9999`.
- Local ignored files: `.env`, `.venv/`.

## Verified in M7 rehearsal

- Compose validation:
  `docker compose --env-file .env -f docker-compose.yml config --quiet`
- Database inventory and constraints:
  `scripts/setup/Test-Database.ps1 -EnvFile .env`
- Replication and cluster state:
  `scripts/setup/Test-Cluster.ps1 -EnvFile .env`
- PostgreSQL role permissions:
  `scripts/setup/Test-Permissions.ps1 -EnvFile .env`
- PgPool load balancing:
  `scripts/demo/Show-PgPoolLoadBalancing.ps1 -EnvFile .env -Samples 60`
- Application smoke test:
  `scripts/demo/Test-Application.ps1 -BaseUrl http://127.0.0.1:8000`
- FastAPI unit/static tests:
  `.venv\Scripts\python.exe -m pytest app/tests -q`
- Repository safety scan:
  `scripts/evidence/Test-RepositorySafety.ps1`
- Whitespace check:
  `git diff --check`
- Backup/restore rehearsal:
  `scripts/backup/Test-BackupRestore.ps1` on isolated project
  `vehicle-insurance-m5-test`.

## Demo run order

1. Show application at `http://127.0.0.1:8000`.
2. Run `scripts/setup/Test-Database.ps1 -EnvFile .env`.
3. Run `scripts/setup/Test-Permissions.ps1 -EnvFile .env`.
4. Run `scripts/demo/Show-PgPoolLoadBalancing.ps1 -EnvFile .env -Samples 60`.
5. Show backup/restore evidence or run the isolated M5 script if time allows.
6. For DR demo, run `scripts/failover/Invoke-SiteAFailover.ps1 -EnvFile .env`.
7. After DR demo, either keep the failed-over state as evidence or rebuild the
   demo cluster with `scripts/failover/Reset-Cluster.ps1 -EnvFile .env -Force`.

## Notes for classroom demo

- Do not open `127.0.0.1:9999` in a browser; it is a PostgreSQL/PgPool SQL
  endpoint, not HTTP.
- Do not paste `.env` values into evidence.
- `repmgr cluster show` output must have `password=REDACTED` if copied.
- The M5 isolated rehearsal creates Docker volumes. Remove them only if you no
  longer need the rehearsal state.

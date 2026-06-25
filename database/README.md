# Baza danych — M1

Skrypty realizują wyłącznie model danych, role, dane demonstracyjne i testy M1.
Nie konfigurują SCRAM, `pg_hba.conf`, replikacji ani pozostałych etapów.

## Kolejność uruchomienia

Wymagany jest administrator PostgreSQL i `psql` z włączonym zatrzymaniem po
błędzie:

```powershell
psql -U postgres -d postgres -f database/migrations/000_database.sql
psql -U postgres -d vehicle_insurance -f database/migrations/001_schema.sql
psql -U postgres -d vehicle_insurance `
  -v agent_password="$env:M1_AGENT_PASSWORD" `
  -v adjuster_password="$env:M1_ADJUSTER_PASSWORD" `
  -v auditor_password="$env:M1_AUDITOR_PASSWORD" `
  -f database/roles/001_roles_and_grants.sql
psql -U postgres -d vehicle_insurance -f database/seed/001_demo_data.sql
```

Hasła nie mają wartości domyślnych i nie mogą być zapisywane w repozytorium.
Skrypt ról kończy się czytelnym błędem, jeśli którejkolwiek zmiennej brakuje.
Migracja schematu oraz seed wymagają pustej bazy; seed działa atomowo.

## Testy

Po migracji, rolach i seedzie:

```powershell
psql -U postgres -d vehicle_insurance -f database/tests/001_inventory.sql
psql -U postgres -d vehicle_insurance -f database/tests/002_constraints.sql

$env:PGPASSWORD = $env:M1_AGENT_PASSWORD
psql -h 127.0.0.1 -U app_agent_anna -d vehicle_insurance `
  -f database/tests/003_agent.sql

$env:PGPASSWORD = $env:M1_ADJUSTER_PASSWORD
psql -h 127.0.0.1 -U app_adjuster_piotr -d vehicle_insurance `
  -f database/tests/004_adjuster.sql

$env:PGPASSWORD = $env:M1_AUDITOR_PASSWORD
psql -h 127.0.0.1 -U app_auditor_ewa -d vehicle_insurance `
  -f database/tests/005_auditor.sql
Remove-Item Env:PGPASSWORD
```

Test agenta celowo zatwierdza jeden fikcyjny rekord, aby audytor mógł
potwierdzić, że `audit.activity_log.database_user` zawiera rzeczywistą rolę
logującą `app_agent_anna`. Pełny test odbiorczy powinien być wykonywany na
jednorazowej instancji PostgreSQL 18.

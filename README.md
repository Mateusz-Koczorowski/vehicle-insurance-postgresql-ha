# B OUT 15 — Ubezpieczenia komunikacyjne

Projekt infrastruktury bazodanowej dla ubezpieczeń komunikacyjnych oparty na
PostgreSQL 18, fizycznej replikacji i PgPool-II. Repozytorium jest przygotowane
do pracy zespołowej oraz późniejszej, siedmiominutowej demonstracji.

## Dokumentacja

- [Wymagania produktu](docs/PRD.md)
- [Projekt bazy danych](docs/DATABASE_DESIGN.md)
- [Plan implementacji](docs/IMPLEMENTATION_PLAN.md)
- [Kontrakt architektoniczny](docs/architecture/ARCHITECTURE_CONTRACT.md)
- [Zasady agentów](docs/agents/README.md)
- [Bramki jakości](docs/agents/QUALITY_GATES.md)

Źródłami prawdy są PRD dla zakresu, projekt bazy dla trzech schematów i ośmiu
tabel, kontrakt architektoniczny dla topologii oraz plan implementacji dla
kolejności prac i kryteriów odbioru.

## Stan implementacji

Etapy M1-M6 dostarczają punktowany rdzeń projektu: model danych, role,
SCRAM/HBA, replikację z repmgr, PgPool-II, backup/restore oraz małą
miniaplikację FastAPI/Jinja. Repozytorium jest przygotowywane do M7:
integracji końcowej, zebrania dowodów i siedmiominutowego demo.

Główny `docker-compose.yml` uruchamia pięć usług wymaganych przez kontrakt:
`insurance-app`, `pgpool`, `pg-primary`, `pg-standby-a` i `pg-standby-dr`.
PostgreSQL oraz PCP nie są publikowane na hoście; aplikacja korzysta z
endpointu `pgpool:9999`.

## Szybka weryfikacja

Nie kopiuj przykładowych wartości do środowiska współdzielonego lub
produkcyjnego.

```powershell
docker compose --env-file .env.example -f docker-compose.yml config --quiet
python -m pytest app/tests -q
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/evidence/Test-RepositorySafety.ps1
git diff --check
```

Opcjonalne uruchomienie demo:

```powershell
Copy-Item .env.example .env
docker compose --env-file .env up -d --build
docker compose ps
```

Po teście usuń lokalny plik `.env`; jest ignorowany przez Git.

## Współpraca

Gałęzie robocze:

- `feature/database`
- `feature/infrastructure`
- `feature/application`
- `feature/documentation`

Gałąź integracyjna to `main`. Commity używają prefiksów `feat:`, `fix:`,
`docs:`, `test:`, `chore:` lub `refactor:`.

Przed przekazaniem zmiany wykonaj checklistę z
[docs/review-checklist.md](docs/review-checklist.md). Nie commituj sekretów,
kluczy prywatnych, certyfikatów generowanych, katalogów danych ani backupów.

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

Etapy 0–2 dostarczają strukturę repozytorium, kontrakt architektoniczny i
szkielet Docker Compose. Węzły PostgreSQL są na tym etapie niezależne:
replikacja, repmgr, właściwa konfiguracja PgPool-II i aplikacja zostaną dodane
w kolejnych etapach. Usługi `pgpool` i `insurance-app` są jawnie oznaczonymi
placeholderami.

## Szybka weryfikacja

Nie kopiuj przykładowych wartości do środowiska współdzielonego lub
produkcyjnego.

```powershell
docker compose --env-file .env.example config
powershell -File scripts/setup/Test-RepositoryStructure.ps1
```

Opcjonalne uruchomienie szkieletu:

```powershell
Copy-Item .env.example .env
docker compose up -d
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

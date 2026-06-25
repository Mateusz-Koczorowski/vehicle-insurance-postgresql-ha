# Agenci projektu

Repozytorium zawiera wspólne, niezależne od narzędzia definicje ról oraz adaptery dla Codex i Claude Code.

## Lokalizacje

```text
docs/agents/        wspólne źródło zasad i zakresów
.codex/agents/      projektowe definicje Codex w TOML
.claude/agents/     projektowe definicje Claude Code w Markdown
AGENTS.md           instrukcje repozytorium ładowane przez Codex
CLAUDE.md           instrukcje repozytorium dla Claude Code
```

Obowiązkowe dokumenty wspólne:

- `COMMON_CONTRACT.md` - własność, współpraca i format raportowania,
- `QUALITY_GATES.md` - standard kodu, testów, bezpieczeństwa oraz bramki 70/70.

## Dostępni agenci

| Agent | Odpowiedzialność | Główny obszar zapisu |
|---|---|---|
| `database-engineer` | model danych, SQL, migracje, role i audyt | `database/` |
| `infrastructure-engineer` | Docker, PostgreSQL, repmgr, PgPool-II, TLS i sieci | `infrastructure/`, główny Compose |
| `backup-recovery-engineer` | pgBackRest, WAL, PITR i test odtworzenia | `infrastructure/pgbackrest/`, `scripts/backup/` |
| `application-engineer` | miniaplikacja FastAPI i jej testy | `app/` |
| `project-integrator` | integracja, testy przekrojowe, dokumentacja i demo | pliki przekrojowe |

## Zalecana kolejność

1. Integrator przygotowuje szkielet repozytorium i kontrakty.
2. Agent bazy tworzy migracje i testy SQL.
3. Agent infrastruktury przygotowuje klaster i routing.
4. Agent backupu rozpoczyna pracę po ustaleniu obrazu PostgreSQL i wolumenów.
5. Agent aplikacji może rozwijać UI równolegle po ustaleniu kontraktu bazy.
6. Integrator scala wyniki i wykonuje testy końcowe.

## Przykładowe wywołania

Codex:

```text
Użyj agenta database-engineer do realizacji etapu 3 z docs/IMPLEMENTATION_PLAN.md.
Po zakończeniu poproś project-integrator o przegląd zgodności z PRD.
```

Claude Code:

```text
Use the database-engineer agent to implement stage 3 from
docs/IMPLEMENTATION_PLAN.md, then use project-integrator to review the result.
```

Po dodaniu lub zmianie definicji agentów uruchom nową sesję narzędzia, aby konfiguracja została ponownie wykryta.

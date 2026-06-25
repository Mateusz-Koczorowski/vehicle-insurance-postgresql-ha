# Rola: database-engineer

## Misja

Zaprojektować i zaimplementować poprawny, bezpieczny model PostgreSQL dla ubezpieczeń komunikacyjnych.

## Własność

Agent jest właścicielem:

- `database/migrations/`,
- `database/seed/`,
- `database/roles/`,
- `database/audit/`,
- testów SQL dotyczących modelu i uprawnień.

## Obowiązki

- tworzenie bazy i schematów,
- tabele, relacje, ograniczenia i indeksy,
- widoki i funkcje biznesowe,
- generowanie numerów klientów, polis i szkód,
- triggery audytowe,
- role grupowe i konta demonstracyjne,
- GRANT, REVOKE i default privileges,
- fikcyjne dane demonstracyjne,
- testy pozytywne i negatywne,
- dokumentowanie komend SQL i wyników.

## Decyzje obowiązujące

- Schematy: `identity`, `insurance`, `claims`, `audit`.
- Role grupowe: `grp_agent`, `grp_claims_adjuster`, `grp_auditor`.
- Brak biznesowego `DELETE` dla klientów, polis, szkód i wypłat.
- Dziennik audytowy jest zapisywany przez bezpieczną funkcję triggerową.
- Sekwencje służą do współbieżnego generowania numerów.

## Poza zakresem

- konfiguracja replikacji,
- konfiguracja PgPool-II,
- Docker networking,
- mechanizm pgBackRest,
- wygląd aplikacji.

## Weryfikacja

Agent powinien udowodnić:

- istnienie wszystkich schematów i tabel,
- poprawność danych seed,
- działanie ograniczeń,
- różnice praw trzech person,
- brak możliwości zmiany audytu przez konta biznesowe,
- zgodność migracji uruchamianych od pustej bazy.

## Obowiązkowe bramki jakości

Agent odpowiada przede wszystkim za:

- `GATE-03` - schematy,
- `GATE-04` - grupy i uprawnienia,
- część SQL `GATE-08` - least privilege, SCRAM-ready role i bezpieczny audyt.

Ponadto:

- każda migracja musi działać w poprawnej kolejności od pustej bazy,
- każda ważna reguła biznesowa ma test pozytywny i negatywny,
- funkcje `SECURITY DEFINER` posiadają bezpieczny `search_path`,
- agent nie może uznać praw za poprawne bez wykonania testów jako rzeczywiste role logujące.

## Handoff

Dla aplikacji agent przekazuje:

- stabilne nazwy tabel i widoków,
- dozwolone operacje person,
- przykładowe zapytania,
- sposób łączenia i nazwy ról.

Dla infrastruktury przekazuje:

- nazwę bazy,
- techniczne role wymagane przy inicjalizacji,
- kolejność uruchamiania migracji.

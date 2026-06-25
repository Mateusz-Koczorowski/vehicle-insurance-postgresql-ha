# Rola: backup-recovery-engineer

## Misja

Zapewnić odtwarzalną kopię bazy i udowodnić odzyskanie danych po logicznym uszkodzeniu, którego replikacja nie cofa.

## Własność

Agent jest właścicielem:

- `infrastructure/pgbackrest/`,
- `scripts/backup/`,
- `scripts/demo/` związanych z backupem i restore,
- testów odtwarzania,
- dokumentacji RPO, RTO, retencji i procedury PITR.

Zmiany głównego obrazu PostgreSQL i Compose wymagają uzgodnienia z `infrastructure-engineer`.

## Obowiązki

- konfiguracja stanza pgBackRest,
- repozytorium w lokalizacji B,
- pełny backup i archiwizacja WAL,
- kontrola `archive-push`,
- retencja demonstracyjna,
- przywracanie do izolowanego kontenera lub katalogu,
- Point-in-Time Recovery do chwili sprzed `DELETE`,
- dodatkowy logiczny eksport struktury,
- skrypty dowodowe i instrukcja awaryjna,
- wyjaśnienie różnicy między replikacją a backupem.

## Decyzje obowiązujące

- Restore nie może niszczyć aktywnego klastra.
- Repozytorium backupu nie trafia do Git.
- WAL jest wymagany do PITR.
- `pg_dump` jest dodatkiem, nie podstawowym mechanizmem Disaster Recovery.
- Test odzyskiwania musi używać jednoznacznego rekordu kontrolnego i czasu docelowego.

## Poza zakresem

- wybór primary po failover,
- routing PgPool-II,
- model biznesowy poza rekordem używanym w teście,
- UI aplikacji.

## Weryfikacja

Agent powinien udowodnić:

- poprawny `stanza-create`,
- pozytywny `pgbackrest check`,
- backup widoczny w `pgbackrest info`,
- archiwizację segmentów WAL,
- usunięcie rekordu w aktywnej bazie,
- obecność rekordu w instancji odtworzonej do wcześniejszego czasu,
- możliwość powtórzenia procedury od czystego stanu.

## Obowiązkowe bramki jakości

Agent odpowiada przede wszystkim za `GATE-07`.

Ponadto:

- pozytywny status backupu bez testu restore nie wystarcza,
- test musi obejmować logiczne usunięcie i odzyskanie konkretnego rekordu,
- docelowy czas PITR musi być jednoznaczny,
- restore odbywa się w izolowanym katalogu lub kontenerze,
- agent dokumentuje RPO, RTO, retencję i ograniczenia demonstracji,
- skrypt nie może usunąć ani nadpisać aktywnego PGDATA.

## Handoff

Integrator otrzymuje:

- dokładny scenariusz demo,
- przewidywany czas restore,
- komendy i zapisane wyniki,
- ograniczenia i plan awaryjny, jeśli pełny restore trwa za długo na prezentację.

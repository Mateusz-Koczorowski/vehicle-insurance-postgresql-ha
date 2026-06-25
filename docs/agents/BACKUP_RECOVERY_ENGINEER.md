# Rola: backup-recovery-engineer

## Misja

Zapewnić prostą kopię logiczną i udowodnić odzyskanie danych po usunięciu, którego replikacja nie cofa.

## Własność

Agent jest właścicielem:

- `scripts/backup/`,
- skryptów demonstracyjnych związanych z backupem i restore,
- testów odtwarzania,
- dokumentacji RPO i procedury restore.

## Obowiązki

- `pg_dump --format=custom`,
- zapis dumpa poza wolumenami aktywnego klastra,
- utworzenie oddzielnej bazy odtworzeniowej,
- `pg_restore`,
- odzyskanie rekordu usuniętego po wykonaniu dumpa,
- skrypty dowodowe,
- wyjaśnienie różnicy między replikacją a backupem.

## Decyzje obowiązujące

- Restore nie nadpisuje aktywnej bazy.
- Pliki dump nie trafiają do Git.
- `pg_dump` jest podstawowym mechanizmem wymaganym w projekcie.
- RPO odpowiada chwili ostatniego wykonanego dumpa.
- pgBackRest, WAL i PITR są rozszerzeniami opcjonalnymi.

## Poza zakresem

- wybór primary po failover,
- routing PgPool-II,
- pgBackRest i PITR bez wyraźnego polecenia,
- model biznesowy poza rekordem kontrolnym,
- UI aplikacji.

## Weryfikacja

Agent powinien udowodnić:

- powstanie poprawnego pliku custom dump,
- usunięcie rekordu w aktywnej bazie,
- odtworzenie dumpa do oddzielnej bazy,
- obecność usuniętego rekordu w bazie odtworzonej,
- możliwość powtórzenia procedury od czystego stanu.

## Obowiązkowe bramki jakości

Agent odpowiada za `GATE-07`.

Istnienie pliku dump bez testu restore nie wystarcza. Skrypt nie może usuwać ani nadpisywać aktywnego PGDATA.

## Handoff

Integrator otrzymuje:

- krótki scenariusz demo,
- czas wykonania dumpa i restore,
- komendy oraz zapisane wyniki,
- jasno opisane RPO i ograniczenia mechanizmu.

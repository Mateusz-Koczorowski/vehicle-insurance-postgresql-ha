# ADR-0003: `pg_dump` i `pg_restore` jako obowiązkowy backup

Status: zaakceptowana.

## Kontekst

Fizyczna replikacja zapewnia dostępność, lecz przenosi na standby również
błędne operacje logiczne, w tym `DELETE`. Projekt musi pokazać odzyskanie
usuniętego rekordu bez nadpisywania aktywnego klastra i bez rozbudowywania
laboratorium ponad wymagania oceny.

## Decyzja

Obowiązkowy mechanizm backupu to:

- `pg_dump --format=custom`;
- przechowywanie dumpa poza wolumenami aktywnego klastra i poza Git;
- utworzenie oddzielnej bazy `vehicle_insurance_restore`;
- odtworzenie przez `pg_restore`;
- potwierdzenie obecności rekordu usuniętego z aktywnej bazy.

## Konsekwencje

Mechanizm jest prosty, powtarzalny i wystarczający do demonstracji różnicy
między wysoką dostępnością a kopią zapasową. RPO odpowiada chwili ostatniego
dumpa. pgBackRest, archiwizacja WAL i PITR pozostają opcjonalnymi
rozszerzeniami, jeśli cały zakres obowiązkowy jest już zaliczony.

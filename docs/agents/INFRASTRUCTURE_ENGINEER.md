# Rola: infrastructure-engineer

## Misja

Zbudować powtarzalne środowisko Docker z PostgreSQL, repmgr i PgPool-II, które demonstruje wysoką dostępność, Disaster Recovery i rozdzielanie odczytów.

## Własność

Agent jest właścicielem:

- głównego `docker-compose.yml`,
- `infrastructure/postgres/`,
- `infrastructure/repmgr/`,
- `infrastructure/pgpool/`,
- `infrastructure/certificates/` z wyjątkiem generowanych sekretów,
- `scripts/setup/`,
- `scripts/failover/`.

Folder `infrastructure/pgbackrest/` jest współdzielony kontraktem z agentem backupu; zmiany interfejsu wymagają koordynacji.

## Obowiązki

- sieci, statyczna adresacja i healthchecki,
- obraz PostgreSQL z wymaganymi narzędziami,
- jeden primary i dwa standby,
- konfiguracja i rejestracja repmgr,
- streaming replication i sloty,
- switchover, failover, fencing i rejoin,
- PgPool-II w trybie streaming replication,
- routing zapisów i load balancing odczytów,
- TLS i precyzyjny `pg_hba.conf`,
- ograniczenie portów i powierzchni administracyjnej,
- test utraty lokalizacji A.

## Decyzje obowiązujące

- Nie używać natywnej replikacji PgPool-II.
- Aplikacja łączy się przez jeden endpoint PgPool-II.
- Lokalizacja A zawiera primary i lokalny standby.
- Lokalizacja B zawiera standby DR.
- Stary primary musi zostać odgrodzony przed promocją DR.
- Węzły bazodanowe nie są publicznie wystawiane bez potrzeby.

## Poza zakresem

- projekt tabel biznesowych,
- interfejs aplikacji,
- implementacja procedury PITR poza kontraktem uruchomieniowym.

## Weryfikacja

Agent powinien wykonać:

- `docker compose config`,
- kontrolę healthchecków,
- `repmgr cluster show`,
- `pg_stat_replication`,
- zapis na primary i odczyt na obu standby,
- `SHOW POOL_NODES`,
- serię odczytów pokazującą rozdzielenie,
- awarię lokalizacji A i zapis po promocji DR,
- kontrolę TLS przez `pg_stat_ssl`.

## Obowiązkowe bramki jakości

Agent odpowiada przede wszystkim za:

- `GATE-02` - zgodność diagramu i uruchomionej architektury,
- `GATE-05` - replikacja i Disaster Recovery,
- `GATE-06` - rozdzielanie zapytań,
- transportową i sieciową część `GATE-08`.

Ponadto:

- Compose musi przechodzić walidację,
- obrazy i wersje muszą być powtarzalne,
- failover musi uwzględniać fencing,
- healthcheck ma sprawdzać gotowość,
- niedostępny lub opóźniony backend nie może otrzymywać zwykłych odczytów,
- porty administracyjne pozostają wewnętrzne.

## Handoff

Dla backupu:

- ścieżki PGDATA,
- użytkownik i transport pgBackRest,
- wolumen repozytorium,
- ustawienia archiwizacji WAL.

Dla aplikacji:

- hostname i port PgPool-II,
- wymagany tryb SSL,
- zachowanie po failover.

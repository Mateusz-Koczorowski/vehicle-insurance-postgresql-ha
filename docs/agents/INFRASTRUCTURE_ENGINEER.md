# Rola: infrastructure-engineer

## Misja

Zbudować powtarzalne środowisko Docker z PostgreSQL, repmgr i PgPool-II, które demonstruje wysoką dostępność, Disaster Recovery i rozdzielanie odczytów.

## Własność

Agent jest właścicielem:

- głównego `docker-compose.yml`,
- `infrastructure/postgres/`,
- `infrastructure/repmgr/`,
- `infrastructure/pgpool/`,
- `scripts/setup/`,
- `scripts/failover/`.

TLS oraz pgBackRest są poza obowiązkowym zakresem.

## Obowiązki

- sieci, statyczna adresacja i healthchecki,
- obraz PostgreSQL z wymaganymi narzędziami,
- jeden primary i dwa standby,
- konfiguracja i rejestracja repmgr,
- streaming replication i sloty,
- failover i fencing,
- PgPool-II w trybie streaming replication,
- routing zapisów i load balancing odczytów,
- SCRAM-SHA-256 i precyzyjny `pg_hba.conf`,
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
- implementacja backupu poza udostępnieniem bezpiecznego endpointu.

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
- odrzucenie połączenia z niedozwolonej roli lub zakresu.

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

- nazwę bazy,
- endpoint i konto używane przez skrypt dump/restore,
- lokalizację dumpa poza wolumenami klastra.

Dla aplikacji:

- hostname i port PgPool-II,
- zachowanie po failover.

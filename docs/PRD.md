# PRD — system bazodanowy ubezpieczeń komunikacyjnych

## 1. Informacje podstawowe

| Pole | Wartość |
|---|---|
| Temat | B OUT 15 — Ubezpieczenia komunikacyjne |
| Repozytorium | `vehicle-insurance-postgresql-ha` |
| Rodzaj projektu | projekt grupowy z administrowania rozproszonymi bazami danych |
| Główna technologia | PostgreSQL 18 |
| Uruchomienie | lokalne środowisko Docker Compose |
| Maksymalna ocena | 70 punktów |
| Czas demonstracji | 7 minut |

## 2. Cel i granice projektu

Celem jest zbudowanie realistycznego, lecz niewielkiego systemu bazodanowego dla
firmy oferującej ubezpieczenia komunikacyjne. Projekt ma przede wszystkim
udowodnić wysoką dostępność PostgreSQL, rozdzielanie odczytów, kontrolę dostępu,
odtwarzanie danych i odporność na utratę całej lokalizacji.

Miniaplikacja webowa dostarcza kontekst domenowy i wygodny interfejs do
demonstracji. Nie jest kompletnym systemem sprzedażowym. Obowiązkowy zakres
obejmuje tylko klientów, pojazdy, polisy, zakresy ochrony, szkody, historię
szkód, wypłaty oraz podstawowy audyt.

## 3. Dlaczego infrastruktura jest kluczowa dla ubezpieczyciela

### 3.1. Ciągłość sprzedaży polis

Agent musi sprawdzić klienta i pojazd, a następnie zapisać polisę. Niedostępność
bazy oznacza zatrzymanie sprzedaży oraz brak możliwości potwierdzenia ochrony.
Dlatego system posiada primary, lokalny standby, standby w lokalizacji DR i
kontrolowaną procedurę przełączenia. Po utracie lokalizacji A zapis musi zostać
wznowiony na promowanym węźle DR.

### 3.2. Całodobowa obsługa szkód

Szkoda może zostać zgłoszona bezpośrednio po wypadku, niezależnie od pory dnia.
Likwidator potrzebuje dostępu do polisy, pojazdu i historii sprawy. Sama kopia
zapasowa nie zapewnia ciągłości pracy, dlatego aktualne dane są fizycznie
replikowane do drugiej lokalizacji.

### 3.3. Przewaga odczytów

Wyszukiwanie klientów, polis, statusów szkód i historii operacji występuje
częściej niż zapis. PgPool-II zapewnia aplikacji jeden endpoint, kieruje zapisy
do primary i rozdziela kwalifikujące się odczyty między zdrowe backendy.
Health check ogranicza kierowanie ruchu do niedostępnych węzłów.

### 3.4. Rozdział obowiązków

Agent sprzedaży nie może zatwierdzać wypłat, likwidator szkód nie może zmieniać
polis, a audytor ma dostęp tylko do odczytu. Ograniczenia wymusza PostgreSQL za
pomocą grup i praw do konkretnych obiektów. Ukrycie przycisku w aplikacji nie
jest mechanizmem bezpieczeństwa.

### 3.5. Awaria całej lokalizacji

Awaria zasilania, hosta lub sieci może wyłączyć jednocześnie primary i lokalny
standby. Projekt symuluje taką utratę lokalizacji A, promuje
`pg-standby-dr`, odgradza stary primary przed ryzykiem split-brain i potwierdza
zapis po failover.

### 3.6. Replikacja nie zastępuje backupu

Fizyczna replikacja szybko przenosi również błędny lub złośliwy `DELETE` na oba
standby. Zapewnia dostępność, ale nie zachowuje niezależnej wersji logicznej
danych. Dlatego projekt wykonuje `pg_dump --format=custom` poza wolumenami
aktywnego klastra, odtwarza go przez `pg_restore` do oddzielnej bazy i pokazuje
odzyskanie usuniętego rekordu.

## 4. Użytkownicy i persony

| Persona | Grupa PostgreSQL | Zakres |
|---|---|---|
| Anna Agent | `grp_agent` | klienci, pojazdy, polisy i zakresy ochrony |
| Piotr Likwidator | `grp_claims_adjuster` | odczyt polis, szkody, zdarzenia i wypłaty |
| Ewa Audytor | `grp_auditor` | odczyt danych biznesowych i audytu |
| Administrator techniczny | role techniczne | klaster, backup, restore i diagnostyka |

Administrator techniczny nie jest personą miniaplikacji.

## 5. Zakres obowiązkowy

### 5.1. Infrastruktura

- trzy węzły PostgreSQL: `pg-primary`, `pg-standby-a`, `pg-standby-dr`;
- dwie symulowane lokalizacje: A i B/DR;
- fizyczna replikacja strumieniowa primary → dwa standby;
- repmgr do rejestracji klastra, monitoringu i ręcznego failover;
- PgPool-II jako jeden endpoint SQL, health check i load balancing odczytów;
- awaria całej lokalizacji A, promocja DR i zapis po failover;
- zabezpieczenie starego primary przed split-brain;
- SCRAM-SHA-256 i precyzyjny `pg_hba.conf`;
- brak publicznych portów PostgreSQL i PCP;
- sekrety poza repozytorium.

### 5.2. Backup i odtworzenie

- `pg_dump --format=custom`;
- plik dumpa poza trzema wolumenami danych aktywnego klastra;
- `pg_restore` do oddzielnej bazy `vehicle_insurance_restore`;
- odzyskanie rekordu usuniętego po wykonaniu dumpa;
- udokumentowanie różnicy między replikacją i backupem.

### 5.3. Baza danych

Baza `vehicle_insurance` zawiera trzy schematy i osiem tabel:

- `insurance.customers`;
- `insurance.vehicles`;
- `insurance.policies`;
- `insurance.policy_coverages`;
- `claims.claims`;
- `claims.claim_events`;
- `claims.payouts`;
- `audit.activity_log`.

Obowiązkowe grupy to:

- `grp_agent`;
- `grp_claims_adjuster`;
- `grp_auditor`.

Projekt zawiera rzeczywiste testy dozwolonych i zabronionych operacji wykonane
jako role logujące przypisane do tych grup.

### 5.4. Miniaplikacja

- wybór jednej z trzech person;
- lista klientów i polis;
- prosty formularz utworzenia polisy;
- lista szkód i zmiana statusu;
- widok dziennika audytu;
- akcje demonstrujące odmowę uprawnień przez PostgreSQL;
- widoczny `current_user` i adres backendu obsługującego zapytanie.

## 6. Zakres opcjonalny

Poniższe rozszerzenia można realizować dopiero po zaliczeniu całego zakresu
obowiązkowego. Ich brak nie oznacza nieukończenia projektu:

- TLS i własne certyfikaty;
- pgBackRest, archiwizacja WAL i PITR;
- automatyczny failover przez `repmgrd`;
- automatyczny rejoin oraz `pg_rewind`;
- PgPool-II Watchdog i drugi PgPool-II;
- rozbudowany CRUD;
- panel infrastruktury i zaawansowane metryki.

Poza projektem pozostają także rzeczywiste płatności składek, taryfikacja,
integracje z rejestrami, obsługa dokumentów, OAuth, Kubernetes i publiczne
wdrożenie internetowe.

## 7. Wymagania funkcjonalne miniaplikacji

### FR-01. Wybór persony

Użytkownik wybiera Annę, Piotra albo Ewę. Hasła ról pozostają po stronie
serwera aplikacji, poza Git. Wybrana persona korzysta z własnej roli logującej.

### FR-02. Informacja diagnostyczna

Każdy ekran pokazuje aktywną personę, wynik `current_user` oraz adres backendu
PostgreSQL. Dane diagnostyczne nie ujawniają haseł ani pełnych DSN.

### FR-03. Klienci i polisy

Agent przegląda klientów i polisy oraz tworzy prostą polisę dla istniejącego
klienta i pojazdu. Likwidator i audytor mają odczyt bez prawa zmiany polisy.

### FR-04. Szkody

Likwidator przegląda szkody i zmienia ich status, co tworzy wpis historii.
Agent i audytor nie mogą wykonywać tej aktualizacji.

### FR-05. Audyt

Audytor przegląda `audit.activity_log`. Żadna persona biznesowa nie może
bezpośrednio modyfikować dziennika.

### FR-06. Odmowa uprawnień

Aplikacja bezpiecznie pokazuje co najmniej:

- próbę utworzenia wypłaty przez agenta;
- próbę zmiany polisy przez likwidatora;
- próbę modyfikacji danych przez audytora.

Komunikat wynika z błędu PostgreSQL, a nie z symulacji w UI.

## 8. Wymagania niefunkcjonalne

### NFR-01. Dostępność i DR

Po utracie lokalizacji A operator może ręcznie promować `pg-standby-dr`,
odświeżyć routing PgPool-II i wznowić zapisy. Automatyczny failover nie jest
wymagany.

### NFR-02. Wydajność

PgPool-II kieruje zapisy wyłącznie do primary i rozdziela bezpieczne odczyty
między zdrowe węzły. Dowodem jest `SHOW POOL_NODES` i seria niezależnych
zapytań identyfikujących backend.

### NFR-03. Odzyskiwanie

RPO odpowiada chwili ostatniego dumpa. Restore odbywa się do oddzielnej bazy i
nie nadpisuje aktywnego klastra.

### NFR-04. Bezpieczeństwo

- `password_encryption = 'scram-sha-256'`;
- uwierzytelnianie sieciowe SCRAM-SHA-256;
- brak sieciowego `trust`;
- brak reguł biznesowych obejmujących `0.0.0.0/0`;
- `pg_hba.conf` ograniczony do wymaganych ról i podsieci;
- zasada najmniejszych uprawnień;
- aplikacja nie łączy się jako superuser ani właściciel bazy;
- zapytania aplikacji są parametryzowane;
- PostgreSQL i PCP nie mają portów publikowanych na hoście.

TLS jest opcjonalnym utwardzeniem transportu, nie wymaganiem ukończenia.

### NFR-05. Powtarzalność i dowody

Konfiguracja, migracje, failover, backup i testy mają postać wersjonowanych
plików lub skryptów. Dowód zawiera polecenie, host lub kontener, istotny wynik i
powiązany punkt oceny.

## 9. Architektura docelowa

Compose definiuje pięć usług, trzy sieci i trzy nazwane wolumeny:

| Usługa | Rola |
|---|---|
| `insurance-app` | mała aplikacja demonstracyjna |
| `pgpool` | jeden endpoint SQL, routing, health check i load balancing |
| `pg-primary` | primary w lokalizacji A |
| `pg-standby-a` | lokalny standby w lokalizacji A |
| `pg-standby-dr` | standby i kandydat do promocji w lokalizacji B |

| Sieć | Przeznaczenie |
|---|---|
| `frontend_net` | aplikacja ↔ PgPool-II |
| `site_a_net` | PgPool-II i węzły lokalizacji A |
| `site_b_net` | PgPool-II, łącze primary i węzeł DR |

| Wolumen | Usługa |
|---|---|
| `pg_primary_data` | `pg-primary` |
| `pg_standby_a_data` | `pg-standby-a` |
| `pg_standby_dr_data` | `pg-standby-dr` |

Szczegółowe adresy, przepływy i diagram określa
[ARCHITECTURE_CONTRACT.md](architecture/ARCHITECTURE_CONTRACT.md).

## 10. Wysoka dostępność i routing

Primary wysyła WAL do obu hot standby. repmgr przechowuje metadane klastra,
rejestruje węzły i wspiera ręczną promocję. W obowiązkowym scenariuszu operator:

1. zatrzymuje `pg-primary` i `pg-standby-a`;
2. potwierdza odgrodzenie starego primary;
3. promuje `pg-standby-dr`;
4. odświeża stan backendów PgPool-II;
5. potwierdza `pg_is_in_recovery() = false`;
6. wykonuje zapis przez jeden endpoint PgPool-II.

Powrót starych węzłów jest kontrolowaną procedurą ponownego sklonowania lub
ręcznego rejoin. Automatyzacja tego procesu jest opcjonalna.

## 11. Backup i restore

Scenariusz obowiązkowy:

1. utworzenie jednoznacznego rekordu kontrolnego;
2. wykonanie dumpa w formacie custom do katalogu hosta ignorowanego przez Git;
3. usunięcie rekordu z aktywnej bazy i potwierdzenie, że brak replikuje się;
4. utworzenie `vehicle_insurance_restore`;
5. odtworzenie dumpa przez `pg_restore`;
6. pokazanie rekordu w bazie odtworzonej;
7. pozostawienie aktywnej bazy bez nadpisywania.

## 12. Model danych i uprawnienia

Szczegółowy model, ograniczenia, indeksy, macierz praw i testy opisuje
[DATABASE_DESIGN.md](DATABASE_DESIGN.md). `public` nie zawiera tabel
biznesowych, a publiczne prawo `CREATE` zostaje odebrane rolom aplikacyjnym.

## 13. Technologia miniaplikacji

Preferowany stos to Python, FastAPI, Jinja2, prosty CSS lub niewielki
JavaScript/HTMX oraz psycopg 3. Renderowanie serwerowe ogranicza kod i pozwala
skupić prezentację na PostgreSQL.

## 14. Mapowanie na kryteria 70/70

| Kryterium | Punkty | Realizacja |
|---|---:|---|
| założenia aplikacji | 5 | domena, użytkownicy, zagrożenia i wymagania w PRD |
| diagram architektury | 10 | dwie lokalizacje, hosty, IP, przepływy i komponenty |
| schematy | 5 | `insurance`, `claims`, `audit` |
| grupy | 5 | trzy grupy i rzeczywiste testy odmowy |
| replikacja/DR | 15 | primary, dwa standby, utrata A i promocja DR |
| wydajność | 15 | PgPool-II, health check i rozdzielenie odczytów |
| backup | 5 | custom dump, oddzielny restore i odzyskany rekord |
| bezpieczeństwo | 10 | SCRAM, precyzyjny HBA, least privilege i brak sekretów |

## 15. Kryteria akceptacji

Projekt jest gotowy, gdy:

1. środowisko uruchamia pięć wymaganych usług;
2. klaster pokazuje jeden primary i dwa standby;
3. zapis z primary jest widoczny na obu standby;
4. PgPool-II kieruje zapisy do primary i rozdziela odczyty;
5. po utracie lokalizacji A promowany DR przyjmuje zapis;
6. istnieją trzy schematy, osiem tabel i trzy grupy;
7. testy potwierdzają operacje dozwolone i zabronione;
8. miniaplikacja realizuje wyłącznie przepływy z sekcji 7;
9. usunięty rekord można odzyskać z niezależnego dumpa;
10. sekrety i wygenerowane dane pozostają poza Git;
11. dowody pokrywają wszystkie kryteria;
12. scenariusz demonstracyjny mieści się w 7 minutach.

## 16. Ryzyka i świadome uproszczenia

| Ryzyko | Ograniczenie |
|---|---|
| split-brain po failover | ręczne fencing i brak automatycznego rejoin w rdzeniu |
| odczyt opóźnionych danych | kontrola stanu i progu opóźnienia w PgPool-II |
| utrata zmian po ostatnim dumpie | jawnie opisane RPO; PITR pozostaje opcjonalny |
| zbyt rozbudowane demo | tylko osiem tabel i sześć prostych funkcji UI |
| błędny `DELETE` na wszystkich replikach | niezależny dump i restore do osobnej bazy |
| ujawnienie sekretów | `.env`, ignorowanie artefaktów i kontrola repozytorium |


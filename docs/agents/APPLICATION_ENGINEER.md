# Rola: application-engineer

## Misja

Zbudować małą aplikację FastAPI, która w czytelny sposób prezentuje domenę ubezpieczeń, rzeczywiste uprawnienia PostgreSQL, rozdzielanie odczytów i zachowanie po failover.

## Własność

Agent jest właścicielem:

- `app/`,
- szablonów, statycznych zasobów i testów aplikacji,
- kontenerowego pliku aplikacji,
- dokumentacji endpointów i przepływów UI.

## Obowiązki

- wybór persony bez formularza hasła,
- osobne połączenie bazodanowe dla każdej persony,
- wybór persony i prosty panel,
- lista klientów i polis,
- prosty formularz polisy,
- lista szkód i zmiana statusu,
- widok audytu,
- diagnostyka aktualnego użytkownika i węzła,
- prezentacja błędów uprawnień,
- obsługa utraty i ponownego zestawienia połączenia,
- testy tras oraz dostępu.

## Decyzje obowiązujące

- FastAPI + Jinja2 + prosty CSS/HTMX lub niewielki JavaScript.
- Aplikacja nie jest rozbudowanym SPA.
- Wybór persony nie omija bazy: każda persona używa własnej roli PostgreSQL.
- Hasła są wyłącznie po stronie serwera i poza Git.
- Aplikacja nie łączy się jako `postgres`, superuser ani właściciel wszystkich tabel.
- SQL jest parametryzowany.

## Poza zakresem

- pełne uwierzytelnianie produkcyjne,
- OAuth,
- zewnętrzne płatności,
- skomplikowany design system,
- zarządzanie klastrem z poziomu UI.
- pełny CRUD wszystkich tabel.

## Weryfikacja

Agent powinien udowodnić:

- wybór trzech person,
- poprawny `current_user`,
- dozwolone operacje każdej persony,
- czytelny błąd dla niedozwolonej operacji,
- wyświetlanie węzła obsługującego odczyt,
- poprawne działanie po krótkiej utracie PgPool-II lub zmianie primary,
- brak sekretów w HTML, logach i repozytorium.

## Obowiązkowe bramki jakości

Agent wspiera:

- `GATE-01` przez zgodny z domeną przepływ aplikacji,
- `GATE-04` przez demonstrację rzeczywistych uprawnień,
- `GATE-06` przez diagnostykę backendów,
- `GATE-08` przez parametryzowany SQL i bezpieczne sekrety.

Ponadto:

- logika UI nie może być jedynym zabezpieczeniem,
- każda persona ma test operacji dozwolonej i zabronionej,
- warstwa HTTP, logika i dostęp do danych pozostają rozdzielone,
- aplikacja nie pokazuje stack trace ani poświadczeń,
- interfejs musi pozostać wystarczająco prosty do prezentacji w 7 minut.
- agent nie dodaje ekranów, które nie wspierają bezpośrednio prezentacji bazy lub infrastruktury.

## Handoff

Integrator otrzymuje:

- listę ekranów używanych w demo,
- testy i komendę uruchomienia,
- zależne widoki/funkcje SQL,
- znane ograniczenia interfejsu.

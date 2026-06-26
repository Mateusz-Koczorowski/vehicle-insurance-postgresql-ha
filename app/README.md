# Aplikacja

Mala aplikacja FastAPI renderowana przez Jinja2. Kazda persona uzywa osobnej
roli PostgreSQL i laczy sie wylacznie przez `pgpool:9999`.

Widoki obejmuja klientow, polisy, szkody i audyt. Przyciski demonstracyjne
wykonuja realne zabronione operacje, a komunikat pochodzi z PostgreSQL.

## Persony

- Anna Agent -> `app_agent_anna`
- Piotr Likwidator -> `app_adjuster_piotr`
- Ewa Audytor -> `app_auditor_ewa`

Hasla tych rol sa pobierane tylko ze zmiennych srodowiskowych procesu serwera.
Uzytkownik nie wpisuje hasla w UI, a aplikacja nie wyswietla DSN.

## Widoki i akcje demo

- `/` wybiera persone.
- `/customers` pokazuje klientow; agent moze dodac prosty rekord klienta.
- `/policies` pokazuje polisy; agent moze utworzyc prosta polise z zakresem.
- `/claims` pokazuje szkody; likwidator moze zmienic status szkody.
- `/audit` pokazuje dziennik audytu dla audytora.

Kazdy ekran pokazuje wybrana persone, `current_user`, adres backendu PostgreSQL
i informacje, czy backend jest w recovery. Akcje odmowy wykonuja rzeczywiste
SQL jako dana rola PostgreSQL:

- agent probuje utworzyc wyplate;
- likwidator probuje zmienic polise;
- audytor probuje zmienic klienta.

SQL w aplikacji uzywa parametrow psycopg, a nie konkatenacji danych formularza.

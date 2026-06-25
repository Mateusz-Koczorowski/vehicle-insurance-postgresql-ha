# Standard jakości i bramki odbioru

Ten dokument jest obowiązkowy dla wszystkich agentów. Zadanie nie jest zakończone wyłącznie dlatego, że kod „działa”. Musi również być bezpieczny, powtarzalny, przetestowany, udokumentowany i powiązany z kryteriami oceny projektu.

## 1. Nadrzędne wymagania

Każda zmiana musi:

1. realizować konkretne wymaganie z `docs/PRD.md`,
2. być zgodna z modelem i architekturą projektu,
3. nie obniżać bezpieczeństwa w celu uproszczenia implementacji,
4. posiadać proporcjonalną weryfikację,
5. być możliwa do odtworzenia z repozytorium,
6. dostarczać dowód potrzebny do końcowej oceny, jeśli dotyczy punktowanego elementu,
7. nie dodawać niepotrzebnej złożoności do siedmiominutowego demo.

## 2. Definition of Ready

Agent może rozpocząć implementację, gdy zna:

- wymaganie i oczekiwany rezultat,
- swój obszar własności,
- zależności od innych modułów,
- kryteria akceptacji,
- sposób weryfikacji,
- wpływ na punkty projektu.

Jeśli kontrakt między modułami jest niejasny, agent najpierw zgłasza potrzebną decyzję integratorowi. Nie powinien samodzielnie ustanawiać sprzecznego interfejsu.

## 3. Definition of Done

Zmiana jest ukończona, gdy:

- implementacja znajduje się we właściwym katalogu,
- konfiguracja i kod nie zawierają sekretów,
- formatowanie i analiza statyczna przechodzą, jeśli są dostępne,
- testy właściwe dla zmiany przechodzą,
- sprawdzono przynajmniej jeden istotny scenariusz negatywny,
- dokumentacja uruchomienia lub zachowania została zaktualizowana,
- ważne komendy i wyniki można zapisać jako dowody,
- agent podał zmienione pliki i wyniki weryfikacji,
- nie pozostały nieopisane obejścia ani ręczne kroki,
- integrator może powtórzyć rezultat bez wiedzy ukrytej w rozmowie.

## 4. Standard kodu

### 4.1. Zasady ogólne

- Preferować małe, jednoznaczne moduły i funkcje.
- Nazwy mają opisywać domenę lub rolę techniczną.
- Unikać duplikacji konfiguracji, SQL i logiki.
- Nie dodawać abstrakcji bez rzeczywistej potrzeby.
- Nie pozostawiać martwego kodu, nieużywanych usług ani zakomentowanych bloków.
- Komentarze wyjaśniają powód lub ograniczenie, a nie przepisują kod.
- Błędy powinny zawierać kontekst, ale nie sekrety.
- Daty i czasy przechowywać jako `timestamptz`, jeśli dotyczą rzeczywistych zdarzeń.
- Kod i dokumentacja używają UTF-8.

### 4.2. Python i FastAPI

- Stosować type hints dla publicznych funkcji.
- Rozdzielić routing HTTP, logikę aplikacyjną i dostęp do danych.
- Konfigurację pobierać ze zmiennych środowiskowych.
- Nie konstruować SQL przez konkatenację tekstu z danymi użytkownika.
- Połączenia i transakcje zawsze poprawnie zamykać.
- Nie zwracać użytkownikowi stack trace ani danych połączeniowych.
- Walidować dane wejściowe po stronie aplikacji, zachowując ograniczenia również w bazie.
- Endpointy diagnostyczne nie mogą ujawniać haseł ani pełnej konfiguracji.

### 4.3. SQL i PostgreSQL

- Migracje muszą mieć stabilną kolejność i działać od pustej bazy.
- Wszystkie tabele posiadają klucze główne.
- Relacje domenowe posiadają klucze obce.
- Reguły biznesowe są chronione ograniczeniami, gdy jest to możliwe.
- Indeksy wynikają z kluczy, unikalności lub rzeczywistych zapytań.
- Generowanie identyfikatorów nie może opierać się na `MAX(id)`.
- Funkcje `SECURITY DEFINER` muszą ustawiać bezpieczny `search_path`.
- Migracje nie mogą wymagać ręcznej edycji wygenerowanych plików klastra.
- Role aplikacyjne nie są właścicielami całej bazy.

### 4.4. PowerShell i Bash

- Skrypt kończy się błędem, gdy krytyczne polecenie się nie powiedzie.
- Skrypt wypisuje nazwę kroku oraz docelowy host lub kontener.
- Ścieżki i argumenty zawierające spacje są poprawnie cytowane.
- Sekrety nie są wypisywane do konsoli.
- Destrukcyjne skrypty mają jednoznaczną nazwę i kontrolę zakresu.
- Skrypt powinien być idempotentny albo dokumentować wymagany stan początkowy.

### 4.5. Docker

- Używać określonych wersji obrazów zamiast niekontrolowanego `latest`, gdy projekt zostanie ustabilizowany.
- Healthcheck ma sprawdzać gotowość usługi, nie tylko istnienie procesu.
- Dane trwałe i generowane nie trafiają do obrazu ani Git.
- Kontenery nie powinny działać jako root bez potrzeby.
- Porty backendów i administracyjne nie są wystawiane bez uzasadnienia.
- Obrazy powinny być możliwie małe i budowane powtarzalnie.

## 5. Standard bezpieczeństwa

Zmiana nie przechodzi odbioru, jeśli:

- zawiera hasło lub klucz prywatny,
- dodaje zdalne `trust`,
- dodaje biznesową regułę `0.0.0.0/0`,
- nadaje aplikacji superusera,
- wyłącza TLS bez udokumentowanej przyczyny,
- pozwala ominąć podział ról przez aplikację,
- zapisuje dane wrażliwe w logach,
- wykorzystuje dynamiczny SQL bez bezpiecznego cytowania,
- wykonuje restore nad aktywnym klastrem,
- może doprowadzić do dwóch aktywnych primary bez fencing.

Minimalne wymagania:

- SCRAM-SHA-256,
- TLS dla połączeń sieciowych,
- najmniejsze wymagane uprawnienia,
- precyzyjne podsieci w `pg_hba.conf`,
- sekrety poza Git,
- parametryzowane zapytania,
- kontrolowane konta techniczne,
- audyt operacji krytycznych.

## 6. Standard testów

### 6.1. Piramida testów

1. Szybkie testy jednostkowe funkcji i walidacji.
2. Testy SQL ograniczeń, funkcji i uprawnień.
3. Testy integracyjne aplikacja-PgPool-II-PostgreSQL.
4. Testy infrastrukturalne replikacji, failover i restore.
5. Krótki test end-to-end odpowiadający scenariuszowi prezentacji.

### 6.2. Minimalny zakres

Każda funkcja punktowana musi posiadać:

- przypadek pozytywny,
- przypadek negatywny,
- dowód rezultatu,
- instrukcję powtórzenia.

Nie wolno oznaczać testu jako zaliczonego bez jego uruchomienia. Jeśli środowisko nie pozwala uruchomić testu, agent raportuje go jako niewykonany wraz z powodem.

## 7. Standard dokumentacji i dowodów

Dowód powinien zawierać:

- nazwę hosta lub kontenera,
- wykonane polecenie,
- istotny wynik,
- krótki opis, co wynik potwierdza,
- powiązany punkt oceny.

Nazwy sugerowanych plików:

```text
docs/evidence/criterion-03-schemas.txt
docs/evidence/criterion-04-roles.txt
docs/evidence/criterion-05-failover.txt
docs/evidence/criterion-06-load-balancing.txt
docs/evidence/criterion-07-pitr.txt
docs/evidence/criterion-08-security.txt
```

Surowe logi można dołączyć, ale główny dowód powinien być krótki i czytelny.

## 8. Bramki punktowe 70/70

### GATE-01: Założenia aplikacji - 5 pkt

Wymagane:

- opis organizacji i krytyczności systemu,
- procesy biznesowe,
- użytkownicy,
- zagrożenia,
- wymagania dostępności, wydajności, odzyskiwania i bezpieczeństwa.

Odbiór:

- dokument jest spójny z implementacją,
- aplikacja demonstracyjna używa terminów z domeny ubezpieczeń komunikacyjnych.

### GATE-02: Architektura - 10 pkt

Wymagane:

- diagram dwóch lokalizacji,
- nazwy i IP hostów,
- powiązania logiczne,
- baza, schematy i komponenty,
- kierunki replikacji, zapytań i backupu.

Odbiór:

- diagram odpowiada rzeczywistemu Compose,
- adresy i nazwy nie są tylko dekoracją.

### GATE-03: Schematy - 5 pkt

Wymagane:

- minimum dwa schematy; projekt zakłada cztery,
- tabele faktycznie umieszczone w schematach,
- prawa `USAGE`,
- dowód `\dn` i `\dt`.

Odbiór:

- `public` nie przechowuje tabel biznesowych,
- relacje między schematami działają.

### GATE-04: Grupy i uprawnienia - 5 pkt

Wymagane:

- minimum dwie grupy; projekt zakłada trzy,
- różne prawa do różnych tabel,
- role logujące przypisane do grup,
- demonstracja operacji dozwolonej i zabronionej.

Odbiór:

- odmowę wymusza PostgreSQL, nie tylko UI,
- istnieje dowód `\du`, `\dp` i błędów uprawnień.

### GATE-05: Replikacja i Disaster Recovery - 15 pkt

Wymagane:

- primary oraz co najmniej jeden standby w innej lokalizacji,
- fizyczna replikacja strumieniowa,
- monitoring stanu,
- promocja DR po utracie lokalizacji podstawowej,
- zapis po failover,
- procedura zabezpieczenia i powrotu starego primary.

Odbiór:

- istnieje dowód danych na standby,
- awaria obejmuje lokalizację, nie tylko pojedynczy proces,
- nie powstaje split-brain.

### GATE-06: Wydajność i rozpraszanie zapytań - 15 pkt

Wymagane:

- PgPool-II przed bazami,
- zapisy do primary,
- bezpieczne odczyty kierowane do wielu zdrowych backendów,
- health check,
- kontrola opóźnienia replikacji,
- seria zapytań pokazująca rozkład.

Odbiór:

- test pokazuje więcej niż jeden backend,
- po awarii niedostępny backend przestaje otrzymywać ruch,
- projekt nie używa niespójnej natywnej replikacji PgPool-II.

### GATE-07: Backup i odtworzenie - 5 pkt

Wymagane:

- pełny backup,
- archiwizacja WAL,
- PITR,
- repozytorium poza lokalizacją podstawową,
- odzyskanie rekordu usuniętego logicznie.

Odbiór:

- restore odbywa się do izolowanego środowiska,
- odzyskany rekord jest pokazany,
- replikacja nie jest przedstawiana jako backup.

### GATE-08: Bezpieczeństwo - 10 pkt

Wymagane:

- SCRAM-SHA-256,
- TLS,
- ograniczone adresy IP,
- zasada najmniejszych uprawnień,
- brak sekretów w Git,
- konta techniczne o ograniczonym celu,
- bezpieczny audyt i parametryzowany SQL.

Odbiór:

- konfiguracja i testy potwierdzają zabezpieczenia,
- istnieje co najmniej jeden test odrzuconego połączenia lub działania.

## 9. Bramka integracyjna

Przed uznaniem projektu za gotowy integrator wykonuje:

1. uruchomienie od czystego checkoutu,
2. migracje i seed,
3. test schematów i ról,
4. test replikacji,
5. test load balancingu,
6. test awarii lokalizacji,
7. test PITR,
8. test miniaplikacji,
9. skan repozytorium pod kątem sekretów i danych generowanych,
10. próbę prezentacji ze stoperem.

## 10. Reguła zatrzymania

Agent ma przerwać i zgłosić problem zamiast tworzyć pozornie działające obejście, gdy:

- wymaganie jest sprzeczne z bezpieczeństwem,
- zmiana narusza kontrakt innego modułu,
- test wymaga destrukcyjnej operacji poza wyznaczonym środowiskiem,
- nie da się udowodnić punktowanego zachowania,
- rozwiązanie zależy od nieudokumentowanego ręcznego kroku,
- istnieje ryzyko utraty danych użytkownika.


# Wspólny kontrakt agentów

## 1. Obowiązkowy kontekst

Każdy agent przed rozpoczęciem pracy czyta:

1. `AGENTS.md`,
2. `docs/PRD.md`,
3. odpowiednie sekcje `docs/DATABASE_DESIGN.md`,
4. odpowiedni etap `docs/IMPLEMENTATION_PLAN.md`,
5. `docs/agents/QUALITY_GATES.md`,
6. swój dokument roli w `docs/agents/`.

Agent nie powinien czytać wszystkich dużych plików danych ani katalogów generowanych, jeśli nie są potrzebne do zadania.

## 2. Priorytety

1. Poprawność i powtarzalność.
2. Pokrycie kryteriów oceny.
3. Bezpieczeństwo danych i sekretów.
4. Możliwość przeprowadzenia siedmiominutowej demonstracji.
5. Prostota rozwiązania.
6. Dodatkowe funkcje.

## 3. Granice zmian

- Agent modyfikuje przede wszystkim swój obszar własności.
- Zmiana pliku należącego do innego agenta wymaga opisania zależności w raporcie.
- Główny `docker-compose.yml`, pliki root i interfejsy między modułami są kontrolowane przez `project-integrator` albo `infrastructure-engineer`.
- Agent nie wykonuje destrukcyjnych operacji na danych użytkownika.
- Agent nie resetuje ani nie nadpisuje cudzych zmian.
- Agent nie wykonuje `git commit`, `push`, merge ani rebase, chyba że użytkownik wyraźnie to zleci.

## 4. Bezpieczeństwo

- Brak prawdziwych sekretów w repozytorium.
- Przykładowe wartości trafiają do `.env.example`.
- `.env`, certyfikaty prywatne, katalogi danych i repozytoria backupów muszą być ignorowane.
- Konta aplikacji nie mogą być superuserami.
- Połączenia sieciowe nie mogą używać `trust`.
- Zapytania aplikacji muszą być parametryzowane.
- Testy backupu i failover muszą jasno oznaczać działania destrukcyjne.

## 5. Jakość implementacji

- Skrypty muszą być idempotentne albo jasno dokumentować wymagany stan początkowy.
- Konfiguracja powinna używać nazw usług zamiast przypadkowych adresów, poza statycznymi IP wymaganymi do dokumentacji.
- Migracje posiadają jednoznaczną kolejność.
- Każdy moduł ma instrukcję uruchomienia i test.
- Wyniki ważne dla oceny są możliwe do zapisania w `docs/evidence/`.

## 6. Kontrakt wyjściowy

Końcowy raport każdego agenta zawiera:

1. **Wynik** - co zostało osiągnięte.
2. **Zmienione pliki** - lista ścieżek.
3. **Weryfikacja** - wykonane komendy i rezultat.
4. **Pokryte wymagania** - odwołania do PRD lub punktów oceny.
5. **Ryzyka lub blokery** - konkretnie, bez ukrywania niepewności.
6. **Handoff** - czego potrzebuje następny agent.
7. **Quality gates** - które bramki zastosowano, zaliczono albo pozostawiono zablokowane.

Raport ma być zwięzły. Surowe logi powinny trafić do pliku dowodowego, nie do odpowiedzi.

## 7. Zasady równoległości

Bezpieczne pary równoległe:

- baza + aplikacja po zamrożeniu kontraktu SQL,
- baza + infrastruktura po ustaleniu nazw bazy i ról,
- aplikacja + backup,
- dokumentacja + testy odczytowe.

Pary wymagające koordynacji:

- infrastruktura + backup przy obrazie PostgreSQL i wolumenach,
- infrastruktura + integrator przy głównym Compose,
- baza + aplikacja przy zmianie nazw tabel, widoków lub funkcji.

Nie uruchamiać równolegle dwóch agentów edytujących ten sam plik.

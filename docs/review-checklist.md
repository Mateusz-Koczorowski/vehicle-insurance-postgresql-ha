# Checklista przeglądu zmian

- [ ] Zmiana realizuje wskazany etap planu lub wymaganie PRD.
- [ ] Nazwy usług, bazy, schematów, ról, portów i sieci są zgodne z kontraktem.
- [ ] Nie dodano sekretów, kluczy prywatnych, certyfikatów ani danych osobowych.
- [ ] Nie dodano katalogów danych PostgreSQL, backupów lub artefaktów restore.
- [ ] Backendowe i administracyjne porty nie zostały publicznie wystawione.
- [ ] Skrypty są powtarzalne albo opisują wymagany stan początkowy.
- [ ] Wykonano test pozytywny i odpowiedni test negatywny.
- [ ] Zaktualizowano dokumentację i komendy możliwe do zapisania jako dowód.
- [ ] Raport wymienia niewykonane testy, ryzyka i zależności.
- [ ] `docker compose --env-file .env.example config` przechodzi, jeśli zmiana dotyczy Compose.

Konwencja commitów: `feat:`, `fix:`, `docs:`, `test:`, `chore:` i
`refactor:`. Commity powinny być małe i dotyczyć jednego spójnego celu.

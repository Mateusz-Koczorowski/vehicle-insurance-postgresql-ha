# ADR-0004: FastAPI z renderowaniem serwerowym

Status: zaakceptowana.

Miniaplikacja użyje FastAPI, Jinja2 i HTMX lub prostego JavaScriptu.
Renderowanie serwerowe ogranicza rozmiar warstwy demonstracyjnej i pozwala
skupić się na zachowaniu bazy. Rozbudowane SPA nie wnosi punktów do
kluczowych bramek replikacji, routingu, backupu i bezpieczeństwa.

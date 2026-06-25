# ADR-0001: Fizyczna replikacja strumieniowa

Status: zaakceptowana.

Używamy natywnej fizycznej replikacji PostgreSQL zarządzanej przez repmgr,
z jednym primary i dwoma hot standby. Nie używamy natywnej replikacji
PgPool-II, ponieważ dublowałaby odpowiedzialność PostgreSQL i zwiększała
ryzyko niespójności po powrocie węzła. Decyzja wspiera GATE-05 i bezpieczny
failover z fencingiem.

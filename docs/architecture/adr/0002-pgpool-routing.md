# ADR-0002: PgPool-II jako endpoint aplikacji

Status: zaakceptowana.

PgPool-II zapewnia jeden endpoint aplikacji, routing zapisów do primary,
load balancing bezpiecznych odczytów, pooling i health check backendów.
Sam HAProxy nie rozpoznaje semantyki zapytań PostgreSQL i nie dostarcza
wymaganego dowodu rozpraszania odczytów. PCP pozostaje portem wewnętrznym.

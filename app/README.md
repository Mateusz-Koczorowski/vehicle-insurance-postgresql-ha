# Aplikacja

Mała aplikacja FastAPI renderowana przez Jinja2. Każda persona używa osobnej
roli PostgreSQL i łączy się wyłącznie przez `pgpool:9999`.

Widoki obejmują klientów, polisy, szkody i audyt. Przyciski demonstracyjne
wykonują realne zabronione operacje, a komunikat pochodzi z PostgreSQL.

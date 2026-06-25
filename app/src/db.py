from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

import psycopg
from psycopg.rows import dict_row

from .config import Persona, connection_kwargs


@contextmanager
def connection(persona: Persona) -> Iterator[psycopg.Connection[dict[str, Any]]]:
    last_error: Exception | None = None
    for attempt in range(2):
        try:
            with psycopg.connect(
                **connection_kwargs(persona),
                row_factory=dict_row,
                autocommit=False,
            ) as conn:
                yield conn
                return
        except psycopg.OperationalError as exc:
            last_error = exc
            if attempt:
                raise
    assert last_error is not None
    raise last_error


def fetch_all(persona: Persona, query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    with connection(persona) as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return list(cur.fetchall())


def diagnostics(persona: Persona) -> dict[str, Any]:
    rows = fetch_all(
        persona,
        """
        SELECT current_user AS database_user,
               inet_server_addr()::text AS backend_address,
               pg_is_in_recovery() AS backend_in_recovery
        """,
    )
    return rows[0]

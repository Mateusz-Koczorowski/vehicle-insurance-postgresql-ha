from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

import psycopg
from fastapi.testclient import TestClient

from src import main


def _patch_diagnostics(monkeypatch: Any) -> None:
    monkeypatch.setattr(
        main,
        "diagnostics",
        lambda persona: {
            "database_user": persona.username,
            "backend_address": "172.46.0.11",
            "backend_in_recovery": False,
        },
    )


def test_home_renders_persona_and_safe_diagnostics(monkeypatch: Any) -> None:
    _patch_diagnostics(monkeypatch)

    response = TestClient(main.app).get("/?persona=auditor")

    assert response.status_code == 200
    assert "Ewa" in response.text
    assert "app_auditor_ewa" in response.text
    assert "172.46.0.11" in response.text
    assert "CHANGE_ME" not in response.text
    assert "postgres://" not in response.text


def test_main_views_render_with_selected_persona(monkeypatch: Any) -> None:
    _patch_diagnostics(monkeypatch)

    def fake_fetch_all(persona: Any, query: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
        if "FROM insurance.customers" in query and "JOIN" not in query:
            return [
                {
                    "customer_id": 1,
                    "customer_number": "CUS-000001",
                    "first_name": "Anna",
                    "last_name": "Test",
                    "email": None,
                    "phone": None,
                }
            ]
        if "FROM insurance.policies" in query:
            return []
        if "FROM insurance.vehicles" in query:
            return []
        if "FROM claims.claims" in query:
            return []
        if "FROM audit.activity_log" in query:
            return []
        raise AssertionError(query)

    monkeypatch.setattr(main, "fetch_all", fake_fetch_all)
    client = TestClient(main.app)

    for path in ("/customers", "/policies", "/claims", "/audit"):
        response = client.get(f"{path}?persona=agent")
        assert response.status_code == 200
        assert "Anna" in response.text


def test_create_customer_uses_agent_role_and_parameterized_sql(monkeypatch: Any) -> None:
    executed: list[tuple[str, tuple[Any, ...]]] = []
    selected_users: list[str] = []

    class Cursor:
        def __enter__(self) -> "Cursor":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def execute(self, query: str, params: tuple[Any, ...]) -> None:
            executed.append((query, params))

        def fetchone(self) -> dict[str, str]:
            return {"customer_number": "CUS-009999"}

    class Conn:
        def __enter__(self) -> "Conn":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def cursor(self) -> Cursor:
            return Cursor()

    @contextmanager
    def fake_connection(persona: Any) -> Iterator[Conn]:
        selected_users.append(persona.username)
        yield Conn()

    monkeypatch.setattr(main, "connection", fake_connection)

    response = TestClient(main.app).post(
        "/customers",
        data={
            "persona": "agent",
            "first_name": "Demo",
            "last_name": "Client",
            "national_id": "12345678901",
            "email": "demo@example.invalid",
            "phone": "555-0100",
        },
        follow_redirects=False,
    )

    assert response.status_code == 303
    assert selected_users == ["app_agent_anna"]
    assert len(executed) == 1
    query, params = executed[0]
    assert "%s" in query
    assert "12345678901" not in query
    assert params == (
        "Demo",
        "Client",
        "12345678901",
        "demo@example.invalid",
        "555-0100",
    )


def test_permission_denial_message_is_redirected_without_secret(monkeypatch: Any) -> None:
    class Cursor:
        def __enter__(self) -> "Cursor":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def execute(self, query: str, params: tuple[Any, ...]) -> None:
            raise psycopg.errors.InsufficientPrivilege("permission denied for table payouts")

    class Conn:
        def __enter__(self) -> "Conn":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def cursor(self) -> Cursor:
            return Cursor()

    @contextmanager
    def fake_connection(persona: Any) -> Iterator[Conn]:
        yield Conn()

    monkeypatch.setattr(main, "connection", fake_connection)

    response = TestClient(main.app).post(
        "/denials/agent-payout",
        data={"persona": "agent"},
        follow_redirects=False,
    )

    assert response.status_code == 303
    location = response.headers["location"]
    assert location.startswith("/claims?persona=agent&message=PostgreSQL")
    assert "password" not in location.lower()
    assert "postgres://" not in location

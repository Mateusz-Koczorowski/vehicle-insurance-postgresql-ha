from src.config import PERSONAS, get_persona


def test_personas_use_distinct_non_superuser_roles() -> None:
    usernames = {persona.username for persona in PERSONAS.values()}
    assert usernames == {
        "app_agent_anna",
        "app_adjuster_piotr",
        "app_auditor_ewa",
    }
    assert "postgres" not in usernames


def test_unknown_persona_falls_back_to_agent() -> None:
    assert get_persona("unknown").key == "agent"

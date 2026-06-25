from dataclasses import dataclass
import os


@dataclass(frozen=True)
class Persona:
    key: str
    label: str
    username: str
    password_env: str


PERSONAS = {
    "agent": Persona("agent", "Anna Agent", "app_agent_anna", "APP_AGENT_PASSWORD"),
    "adjuster": Persona(
        "adjuster",
        "Piotr Likwidator",
        "app_adjuster_piotr",
        "APP_ADJUSTER_PASSWORD",
    ),
    "auditor": Persona(
        "auditor",
        "Ewa Audytor",
        "app_auditor_ewa",
        "APP_AUDITOR_PASSWORD",
    ),
}


def get_persona(key: str) -> Persona:
    return PERSONAS.get(key, PERSONAS["agent"])


def connection_kwargs(persona: Persona) -> dict[str, object]:
    password = os.environ.get(persona.password_env)
    if not password:
        raise RuntimeError(f"Missing server-side credential: {persona.password_env}")
    return {
        "host": os.environ.get("DATABASE_HOST", "pgpool"),
        "port": int(os.environ.get("DATABASE_PORT", "9999")),
        "dbname": os.environ.get("DATABASE_NAME", "vehicle_insurance"),
        "user": persona.username,
        "password": password,
        "application_name": f"insurance-demo-{persona.key}",
        "connect_timeout": 5,
    }

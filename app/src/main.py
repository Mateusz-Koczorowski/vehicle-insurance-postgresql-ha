from datetime import date
from pathlib import Path
from typing import Annotated
from urllib.parse import urlencode

from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from psycopg import Error as PsycopgError

from .config import PERSONAS, Persona, get_persona
from .db import connection, diagnostics, fetch_all

BASE_DIR = Path(__file__).resolve().parent.parent
templates = Jinja2Templates(directory=BASE_DIR / "templates")

app = FastAPI(title="Vehicle Insurance HA Demo")
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")


def page_context(request: Request, persona: Persona, **extra: object) -> dict[str, object]:
    context: dict[str, object] = {
        "request": request,
        "persona": persona,
        "personas": PERSONAS.values(),
        "diagnostics": diagnostics(persona),
    }
    context.update(extra)
    return context


def database_error_message(exc: PsycopgError) -> str:
    message = exc.diag.message_primary or "PostgreSQL rejected the operation."
    return f"PostgreSQL: {message}"


def redirect_with_message(path: str, persona: Persona, message: str) -> RedirectResponse:
    query = urlencode({"persona": persona.key, "message": message})
    return RedirectResponse(f"{path}?{query}", status_code=303)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/", response_class=HTMLResponse)
def home(request: Request, persona: str = "agent") -> HTMLResponse:
    selected = get_persona(persona)
    return templates.TemplateResponse(
        request,
        "index.html",
        page_context(request, selected),
    )


@app.get("/customers", response_class=HTMLResponse)
def customers(request: Request, persona: str = "agent", message: str = "") -> HTMLResponse:
    selected = get_persona(persona)
    rows = fetch_all(
        selected,
        """
        SELECT customer_id, customer_number, first_name, last_name, email, phone
        FROM insurance.customers
        ORDER BY last_name, first_name
        """,
    )
    return templates.TemplateResponse(
        request,
        "customers.html",
        page_context(request, selected, customers=rows, message=message),
    )


@app.post("/customers")
def create_customer(
    persona: Annotated[str, Form()],
    first_name: Annotated[str, Form(min_length=1, max_length=80)],
    last_name: Annotated[str, Form(min_length=1, max_length=100)],
    national_id: Annotated[str, Form(pattern=r"^[0-9]{11}$")],
    email: Annotated[str, Form(max_length=254)] = "",
    phone: Annotated[str, Form(max_length=30)] = "",
) -> RedirectResponse:
    selected = get_persona(persona)
    try:
        with connection(selected) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO insurance.customers(
                        first_name, last_name, national_id, email, phone
                    )
                    VALUES (%s, %s, %s, NULLIF(%s, ''), NULLIF(%s, ''))
                    RETURNING customer_number
                    """,
                    (
                        first_name.strip(),
                        last_name.strip(),
                        national_id,
                        email.strip(),
                        phone.strip(),
                    ),
                )
                customer = cur.fetchone()
                assert customer is not None
        message = f"Created customer {customer['customer_number']}."
    except PsycopgError as exc:
        message = database_error_message(exc)
    return redirect_with_message("/customers", selected, message)


@app.get("/policies", response_class=HTMLResponse)
def policies(request: Request, persona: str = "agent", message: str = "") -> HTMLResponse:
    selected = get_persona(persona)
    rows = fetch_all(
        selected,
        """
        SELECT p.policy_id, p.policy_number, p.status, p.valid_from, p.valid_to,
               p.total_premium, c.customer_number,
               c.first_name || ' ' || c.last_name AS customer_name,
               v.registration_number, v.make || ' ' || v.model AS vehicle_name
        FROM insurance.policies p
        JOIN insurance.customers c ON c.customer_id = p.customer_id
        JOIN insurance.vehicles v ON v.vehicle_id = p.vehicle_id
        ORDER BY p.policy_id DESC
        """,
    )
    vehicles = fetch_all(
        selected,
        """
        SELECT v.vehicle_id, v.owner_customer_id, v.registration_number,
               v.make || ' ' || v.model AS vehicle_name,
               c.first_name || ' ' || c.last_name AS owner_name
        FROM insurance.vehicles v
        JOIN insurance.customers c ON c.customer_id = v.owner_customer_id
        ORDER BY v.vehicle_id
        """,
    )
    return templates.TemplateResponse(
        request,
        "policies.html",
        page_context(request, selected, policies=rows, vehicles=vehicles, message=message),
    )


@app.post("/policies")
def create_policy(
    persona: Annotated[str, Form()],
    customer_id: Annotated[int, Form()],
    vehicle_id: Annotated[int, Form()],
    valid_from: Annotated[date, Form()],
    valid_to: Annotated[date, Form()],
    total_premium: Annotated[float, Form()],
    coverage_code: Annotated[str, Form()],
    insured_limit: Annotated[float, Form()],
) -> RedirectResponse:
    selected = get_persona(persona)
    message: str
    try:
        with connection(selected) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO insurance.policies(
                        customer_id, vehicle_id, status,
                        valid_from, valid_to, total_premium
                    )
                    VALUES (%s, %s, 'DRAFT', %s, %s, %s)
                    RETURNING policy_id, policy_number
                    """,
                    (customer_id, vehicle_id, valid_from, valid_to, total_premium),
                )
                policy = cur.fetchone()
                assert policy is not None
                cur.execute(
                    """
                    INSERT INTO insurance.policy_coverages(
                        policy_id, coverage_code, insured_limit,
                        deductible, premium_amount
                    )
                    VALUES (%s, %s, %s, 0, %s)
                    """,
                    (policy["policy_id"], coverage_code, insured_limit, total_premium),
                )
                cur.execute(
                    "UPDATE insurance.policies SET status = 'ACTIVE' WHERE policy_id = %s",
                    (policy["policy_id"],),
                )
                message = f"Created {policy['policy_number']}."
    except PsycopgError as exc:
        message = database_error_message(exc)
    return redirect_with_message("/policies", selected, message)


@app.get("/claims", response_class=HTMLResponse)
def claims(request: Request, persona: str = "adjuster", message: str = "") -> HTMLResponse:
    selected = get_persona(persona)
    rows = fetch_all(
        selected,
        """
        SELECT cl.claim_id, cl.claim_number, cl.status, cl.incident_at,
               cl.reported_at, cl.description, cl.estimated_loss,
               p.policy_number, v.registration_number
        FROM claims.claims cl
        JOIN insurance.policies p ON p.policy_id = cl.policy_id
        JOIN insurance.vehicles v ON v.vehicle_id = cl.vehicle_id
        ORDER BY cl.reported_at DESC
        """,
    )
    return templates.TemplateResponse(
        request,
        "claims.html",
        page_context(request, selected, claims=rows, message=message),
    )


@app.post("/claims/{claim_id}/status")
def update_claim_status(
    claim_id: int,
    persona: Annotated[str, Form()],
    status: Annotated[str, Form()],
) -> RedirectResponse:
    selected = get_persona(persona)
    try:
        with connection(selected) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE claims.claims SET status = %s WHERE claim_id = %s",
                    (status, claim_id),
                )
                if cur.rowcount != 1:
                    raise ValueError("Claim not found")
        message = f"Claim {claim_id} changed to {status}."
    except PsycopgError as exc:
        message = database_error_message(exc)
    except ValueError as exc:
        message = str(exc)
    return redirect_with_message("/claims", selected, message)


@app.get("/audit", response_class=HTMLResponse)
def audit(request: Request, persona: str = "auditor", message: str = "") -> HTMLResponse:
    selected = get_persona(persona)
    try:
        rows = fetch_all(
            selected,
            """
            SELECT activity_id, occurred_at, database_user, action,
                   schema_name, table_name, record_key
            FROM audit.activity_log
            ORDER BY activity_id DESC
            LIMIT 100
            """,
        )
    except PsycopgError as exc:
        rows = []
        message = database_error_message(exc)
    return templates.TemplateResponse(
        request,
        "audit.html",
        page_context(request, selected, activity=rows, message=message),
    )


@app.post("/denials/{scenario}")
def demonstrate_denial(
    scenario: str,
    persona: Annotated[str, Form()],
) -> RedirectResponse:
    selected = get_persona(persona)
    statements = {
        "agent-payout": (
            "INSERT INTO claims.payouts(claim_id, amount) VALUES (%s, %s)",
            (1, 100.00),
        ),
        "adjuster-policy": (
            "UPDATE insurance.policies SET total_premium = total_premium + 1 "
            "WHERE policy_id = %s",
            (1,),
        ),
        "auditor-customer": (
            "UPDATE insurance.customers SET phone = %s WHERE customer_id = %s",
            ("forbidden", 1),
        ),
    }
    target = {
        "agent-payout": "claims",
        "adjuster-policy": "policies",
        "auditor-customer": "audit",
    }.get(scenario, "")
    if not target or scenario not in statements:
        return RedirectResponse(f"/?persona={selected.key}", status_code=303)

    query, params = statements[scenario]
    try:
        with connection(selected) as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
        message = "Unexpectedly allowed; review database grants."
    except PsycopgError as exc:
        message = database_error_message(exc)
    return redirect_with_message(f"/{target}", selected, message)

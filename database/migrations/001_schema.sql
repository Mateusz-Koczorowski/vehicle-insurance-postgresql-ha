\set ON_ERROR_STOP on

BEGIN;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA insurance;
CREATE SCHEMA claims;
CREATE SCHEMA audit;

CREATE SEQUENCE insurance.customer_number_seq START WITH 1001;
CREATE SEQUENCE insurance.policy_number_seq START WITH 1001;
CREATE SEQUENCE claims.claim_number_seq START WITH 1001;

CREATE TABLE insurance.customers (
    customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_number varchar(20) NOT NULL UNIQUE
        DEFAULT ('CUS-' || lpad(nextval('insurance.customer_number_seq')::text, 6, '0')),
    first_name varchar(80) NOT NULL,
    last_name varchar(100) NOT NULL,
    national_id char(11) NOT NULL UNIQUE
        CHECK (national_id ~ '^[0-9]{11}$'),
    email varchar(254) UNIQUE,
    phone varchar(30),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE insurance.vehicles (
    vehicle_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_customer_id bigint NOT NULL
        REFERENCES insurance.customers(customer_id) ON DELETE RESTRICT,
    vin char(17) NOT NULL UNIQUE
        CHECK (vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),
    registration_number varchar(16) NOT NULL UNIQUE,
    make varchar(80) NOT NULL,
    model varchar(80) NOT NULL,
    production_year smallint NOT NULL
        CHECK (production_year BETWEEN 1886 AND 2100)
);

CREATE TABLE insurance.policies (
    policy_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_number varchar(24) NOT NULL UNIQUE
        DEFAULT ('POL-' || to_char(current_date, 'YYYY') || '-' ||
                 lpad(nextval('insurance.policy_number_seq')::text, 6, '0')),
    customer_id bigint NOT NULL
        REFERENCES insurance.customers(customer_id) ON DELETE RESTRICT,
    vehicle_id bigint NOT NULL
        REFERENCES insurance.vehicles(vehicle_id) ON DELETE RESTRICT,
    status varchar(16) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'EXPIRED', 'CANCELLED')),
    valid_from date NOT NULL,
    valid_to date NOT NULL,
    total_premium numeric(12,2) NOT NULL CHECK (total_premium >= 0),
    created_by varchar(128) NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CHECK (valid_to >= valid_from)
);

CREATE TABLE insurance.policy_coverages (
    policy_coverage_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    policy_id bigint NOT NULL
        REFERENCES insurance.policies(policy_id) ON DELETE CASCADE,
    coverage_code varchar(20) NOT NULL
        CHECK (coverage_code IN ('OC', 'AC', 'ASSISTANCE', 'NNW')),
    insured_limit numeric(14,2) NOT NULL CHECK (insured_limit >= 0),
    deductible numeric(12,2) NOT NULL DEFAULT 0 CHECK (deductible >= 0),
    premium_amount numeric(12,2) NOT NULL CHECK (premium_amount >= 0),
    UNIQUE (policy_id, coverage_code)
);

CREATE TABLE claims.claims (
    claim_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_number varchar(24) NOT NULL UNIQUE
        DEFAULT ('CLM-' || to_char(current_date, 'YYYY') || '-' ||
                 lpad(nextval('claims.claim_number_seq')::text, 6, '0')),
    policy_id bigint NOT NULL
        REFERENCES insurance.policies(policy_id) ON DELETE RESTRICT,
    vehicle_id bigint NOT NULL
        REFERENCES insurance.vehicles(vehicle_id) ON DELETE RESTRICT,
    status varchar(20) NOT NULL DEFAULT 'REPORTED'
        CHECK (status IN ('REPORTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'CLOSED')),
    incident_at timestamptz NOT NULL,
    reported_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    description text NOT NULL,
    estimated_loss numeric(14,2) NOT NULL CHECK (estimated_loss >= 0),
    assigned_adjuster varchar(128),
    CHECK (incident_at <= reported_at)
);

CREATE TABLE claims.claim_events (
    claim_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id bigint NOT NULL
        REFERENCES claims.claims(claim_id) ON DELETE CASCADE,
    event_type varchar(30) NOT NULL
        CHECK (event_type IN (
            'REPORTED', 'DOCUMENT_RECEIVED', 'INSPECTION',
            'STATUS_CHANGED', 'DECISION', 'NOTE'
        )),
    note text NOT NULL,
    created_by varchar(128) NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE claims.payouts (
    payout_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id bigint NOT NULL
        REFERENCES claims.claims(claim_id) ON DELETE RESTRICT,
    amount numeric(14,2) NOT NULL CHECK (amount > 0),
    status varchar(16) NOT NULL DEFAULT 'PROPOSED'
        CHECK (status IN ('PROPOSED', 'APPROVED', 'PAID', 'REJECTED')),
    approved_by varchar(128),
    approved_at timestamptz,
    paid_at timestamptz,
    CHECK (
        (status = 'PROPOSED' AND approved_by IS NULL AND approved_at IS NULL AND paid_at IS NULL)
        OR (status = 'APPROVED' AND approved_by IS NOT NULL AND approved_at IS NOT NULL AND paid_at IS NULL)
        OR (status = 'PAID' AND approved_by IS NOT NULL AND approved_at IS NOT NULL
            AND paid_at IS NOT NULL AND paid_at >= approved_at)
        OR (status = 'REJECTED' AND paid_at IS NULL)
    )
);

CREATE TABLE audit.activity_log (
    activity_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    database_user text NOT NULL,
    application_name text,
    client_addr inet,
    action text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    schema_name text NOT NULL,
    table_name text NOT NULL,
    record_key jsonb NOT NULL,
    old_data jsonb,
    new_data jsonb,
    transaction_id bigint NOT NULL DEFAULT txid_current()
);

CREATE INDEX customers_name_idx ON insurance.customers(last_name, first_name);
CREATE INDEX vehicles_owner_idx ON insurance.vehicles(owner_customer_id);
CREATE INDEX policies_customer_status_idx ON insurance.policies(customer_id, status);
CREATE INDEX policies_vehicle_status_idx ON insurance.policies(vehicle_id, status);
CREATE INDEX policies_validity_idx ON insurance.policies(valid_from, valid_to);
CREATE INDEX policy_coverages_policy_idx ON insurance.policy_coverages(policy_id);
CREATE INDEX claims_policy_idx ON claims.claims(policy_id);
CREATE INDEX claims_vehicle_idx ON claims.claims(vehicle_id);
CREATE INDEX claims_status_reported_idx ON claims.claims(status, reported_at);
CREATE INDEX claim_events_claim_created_idx ON claims.claim_events(claim_id, created_at);
CREATE INDEX payouts_claim_status_idx ON claims.payouts(claim_id, status);
CREATE INDEX activity_log_occurred_idx ON audit.activity_log(occurred_at);
CREATE INDEX activity_log_object_idx ON audit.activity_log(schema_name, table_name);

CREATE FUNCTION insurance.set_customer_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
END;
$$;

CREATE TRIGGER customers_set_updated_at
BEFORE UPDATE ON insurance.customers
FOR EACH ROW EXECUTE FUNCTION insurance.set_customer_updated_at();

CREATE FUNCTION insurance.validate_policy_vehicle_owner()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM insurance.vehicles AS v
        WHERE v.vehicle_id = NEW.vehicle_id
          AND v.owner_customer_id = NEW.customer_id
    ) THEN
        RAISE EXCEPTION 'vehicle % does not belong to customer %',
            NEW.vehicle_id, NEW.customer_id USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER policies_validate_vehicle_owner
BEFORE INSERT OR UPDATE OF customer_id, vehicle_id ON insurance.policies
FOR EACH ROW EXECUTE FUNCTION insurance.validate_policy_vehicle_owner();

CREATE FUNCTION insurance.validate_active_policy()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NEW.status = 'ACTIVE'
       AND NOT EXISTS (
           SELECT 1
           FROM insurance.policy_coverages AS pc
           WHERE pc.policy_id = NEW.policy_id
       )
    THEN
        RAISE EXCEPTION 'active policy % requires at least one coverage',
            NEW.policy_id USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER policies_validate_activation
AFTER INSERT OR UPDATE OF status ON insurance.policies
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION insurance.validate_active_policy();

CREATE FUNCTION insurance.prevent_empty_active_policy()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
DECLARE
    checked_policy_id bigint := OLD.policy_id;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM insurance.policies AS p
        WHERE p.policy_id = checked_policy_id
          AND p.status = 'ACTIVE'
    ) AND NOT EXISTS (
        SELECT 1
        FROM insurance.policy_coverages AS pc
        WHERE pc.policy_id = checked_policy_id
    ) THEN
        RAISE EXCEPTION 'active policy % requires at least one coverage',
            checked_policy_id USING ERRCODE = '23514';
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE CONSTRAINT TRIGGER coverages_preserve_active_policy
AFTER DELETE OR UPDATE OF policy_id ON insurance.policy_coverages
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION insurance.prevent_empty_active_policy();

CREATE FUNCTION claims.validate_claim_vehicle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM insurance.policies AS p
        WHERE p.policy_id = NEW.policy_id
          AND p.vehicle_id = NEW.vehicle_id
    ) THEN
        RAISE EXCEPTION 'vehicle % is not covered by policy %',
            NEW.vehicle_id, NEW.policy_id USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER claims_validate_vehicle
BEFORE INSERT OR UPDATE OF policy_id, vehicle_id ON claims.claims
FOR EACH ROW EXECUTE FUNCTION claims.validate_claim_vehicle();

CREATE FUNCTION claims.record_claim_status_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO claims.claim_events(claim_id, event_type, note, created_by)
        VALUES (
            NEW.claim_id,
            'STATUS_CHANGED',
            format('Status changed from %s to %s', OLD.status, NEW.status),
            session_user
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER claims_record_status_event
AFTER UPDATE OF status ON claims.claims
FOR EACH ROW EXECUTE FUNCTION claims.record_claim_status_event();

CREATE FUNCTION audit.capture_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
    row_old jsonb;
    row_new jsonb;
    row_key jsonb;
BEGIN
    row_old := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END;
    row_new := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END;
    row_key := jsonb_build_object(
        TG_ARGV[0],
        COALESCE(row_new -> TG_ARGV[0], row_old -> TG_ARGV[0])
    );

    INSERT INTO audit.activity_log(
        database_user, application_name, client_addr, action,
        schema_name, table_name, record_key, old_data, new_data
    )
    VALUES (
        session_user,
        current_setting('application_name', true),
        inet_client_addr(),
        TG_OP,
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        row_key,
        row_old,
        row_new
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION claims.record_claim_status_event() FROM PUBLIC;
REVOKE ALL ON FUNCTION audit.capture_change() FROM PUBLIC;

CREATE TRIGGER audit_customers
AFTER INSERT OR UPDATE OR DELETE ON insurance.customers
FOR EACH ROW EXECUTE FUNCTION audit.capture_change('customer_id');
CREATE TRIGGER audit_vehicles
AFTER INSERT OR UPDATE OR DELETE ON insurance.vehicles
FOR EACH ROW EXECUTE FUNCTION audit.capture_change('vehicle_id');
CREATE TRIGGER audit_policies
AFTER INSERT OR UPDATE OR DELETE ON insurance.policies
FOR EACH ROW EXECUTE FUNCTION audit.capture_change('policy_id');
CREATE TRIGGER audit_policy_coverages
AFTER INSERT OR UPDATE OR DELETE ON insurance.policy_coverages
FOR EACH ROW EXECUTE FUNCTION audit.capture_change('policy_coverage_id');
CREATE TRIGGER audit_claims
AFTER INSERT OR UPDATE OR DELETE ON claims.claims
FOR EACH ROW EXECUTE FUNCTION audit.capture_change('claim_id');
CREATE TRIGGER audit_claim_events
AFTER INSERT OR UPDATE OR DELETE ON claims.claim_events
FOR EACH ROW EXECUTE FUNCTION audit.capture_change('claim_event_id');
CREATE TRIGGER audit_payouts
AFTER INSERT OR UPDATE OR DELETE ON claims.payouts
FOR EACH ROW EXECUTE FUNCTION audit.capture_change('payout_id');

CREATE VIEW insurance.active_policy_summary AS
SELECT p.policy_id, p.policy_number, p.status, p.valid_from, p.valid_to,
       c.customer_number, c.first_name, c.last_name,
       v.registration_number, v.make, v.model
FROM insurance.policies AS p
JOIN insurance.customers AS c ON c.customer_id = p.customer_id
JOIN insurance.vehicles AS v ON v.vehicle_id = p.vehicle_id
WHERE p.status = 'ACTIVE';

CREATE VIEW claims.open_claim_summary AS
SELECT cl.claim_id, cl.claim_number, cl.status, cl.reported_at,
       p.policy_number, v.registration_number, cl.estimated_loss
FROM claims.claims AS cl
JOIN insurance.policies AS p ON p.policy_id = cl.policy_id
JOIN insurance.vehicles AS v ON v.vehicle_id = cl.vehicle_id
WHERE cl.status NOT IN ('REJECTED', 'CLOSED');

CREATE VIEW audit.recent_activity AS
SELECT activity_id, occurred_at, database_user, application_name, client_addr,
       action, schema_name, table_name, record_key, transaction_id
FROM audit.activity_log
ORDER BY occurred_at DESC;

COMMIT;

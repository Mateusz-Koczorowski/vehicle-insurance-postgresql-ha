\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    test_customer_id bigint;
    test_vehicle_id bigint;
    test_policy_id bigint;
    test_claim_id bigint;
    event_count integer;
    audit_count integer;
BEGIN
    BEGIN
        INSERT INTO insurance.vehicles
            (owner_customer_id, vin, registration_number, make, model, production_year)
        VALUES (1, 'BADVIN', 'TSTVIN', 'Test', 'Invalid', 2020);
        RAISE EXCEPTION 'invalid VIN was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO insurance.policies
            (policy_number, customer_id, vehicle_id, valid_from, valid_to, total_premium)
        VALUES ('POL-2026-000001', 1, 1, current_date, current_date + 365, 100);
        RAISE EXCEPTION 'duplicate policy number was accepted';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO insurance.policies
            (customer_id, vehicle_id, valid_from, valid_to, total_premium)
        VALUES (1, 1, current_date, current_date - 1, 100);
        RAISE EXCEPTION 'invalid policy date range was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO insurance.policies
            (customer_id, vehicle_id, valid_from, valid_to, total_premium)
        VALUES (2, 1, current_date, current_date + 365, 100);
        RAISE EXCEPTION 'policy for another customer vehicle was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO insurance.policies
            (customer_id, vehicle_id, status, valid_from, valid_to, total_premium)
        VALUES (1, 1, 'ACTIVE', current_date, current_date + 365, 100);
        SET CONSTRAINTS insurance.policies_validate_activation IMMEDIATE;
        RAISE EXCEPTION 'active policy without coverage was accepted';
    EXCEPTION WHEN check_violation THEN
        SET CONSTRAINTS insurance.policies_validate_activation DEFERRED;
    END;

    BEGIN
        INSERT INTO claims.claims
            (policy_id, vehicle_id, incident_at, description, estimated_loss)
        VALUES (1, 2, clock_timestamp(), 'wrong vehicle', 100);
        RAISE EXCEPTION 'claim for uncovered vehicle was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO claims.payouts(claim_id, amount) VALUES (1, -1);
        RAISE EXCEPTION 'negative payout was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    INSERT INTO insurance.customers(first_name, last_name, national_id, email)
    VALUES ('Test', 'Constraint', '99123199991', 'constraint@example.test')
    RETURNING customer_id INTO test_customer_id;

    INSERT INTO insurance.vehicles(
        owner_customer_id, vin, registration_number, make, model, production_year
    )
    VALUES (
        test_customer_id, 'WVWZZZ1JZXW999991', 'TST991', 'Test', 'Car', 2024
    )
    RETURNING vehicle_id INTO test_vehicle_id;

    INSERT INTO insurance.policies(
        customer_id, vehicle_id, status, valid_from, valid_to, total_premium
    )
    VALUES (
        test_customer_id, test_vehicle_id, 'ACTIVE',
        current_date, current_date + 365, 500
    )
    RETURNING policy_id INTO test_policy_id;

    INSERT INTO insurance.policy_coverages(
        policy_id, coverage_code, insured_limit, deductible, premium_amount
    )
    VALUES (test_policy_id, 'OC', 5000000, 0, 500);
    SET CONSTRAINTS insurance.policies_validate_activation IMMEDIATE;

    INSERT INTO claims.claims(
        policy_id, vehicle_id, incident_at, description, estimated_loss
    )
    VALUES (
        test_policy_id, test_vehicle_id, clock_timestamp(),
        'valid test claim', 1000
    )
    RETURNING claim_id INTO test_claim_id;

    UPDATE claims.claims SET status = 'UNDER_REVIEW' WHERE claim_id = test_claim_id;

    SELECT count(*) INTO event_count
    FROM claims.claim_events
    WHERE claim_id = test_claim_id AND event_type = 'STATUS_CHANGED';
    IF event_count <> 1 THEN
        RAISE EXCEPTION 'status update did not create exactly one claim event';
    END IF;

    SELECT count(*) INTO audit_count
    FROM audit.activity_log
    WHERE schema_name = 'insurance'
      AND table_name = 'customers'
      AND record_key = jsonb_build_object('customer_id', test_customer_id);
    IF audit_count <> 1 THEN
        RAISE EXCEPTION 'business insert did not create audit entry';
    END IF;
END;
$$;

ROLLBACK;
SELECT 'constraint and business trigger tests: PASS' AS result;

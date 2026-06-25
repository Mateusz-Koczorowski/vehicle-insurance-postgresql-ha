\set ON_ERROR_STOP on

SELECT count(*) FROM insurance.customers;

INSERT INTO insurance.customers(first_name, last_name, national_id, email)
VALUES ('AnnaTest', 'RoleTest', '99123190001', 'anna.role@example.test');

BEGIN;
DO $$
DECLARE
    customer_id_value bigint;
    vehicle_id_value bigint;
    policy_id_value bigint;
BEGIN
    INSERT INTO insurance.customers(first_name, last_name, national_id, email)
    VALUES ('AnnaPolicy', 'RoleTest', '99123190002', 'anna.policy@example.test')
    RETURNING customer_id INTO customer_id_value;

    INSERT INTO insurance.vehicles(
        owner_customer_id, vin, registration_number, make, model, production_year
    )
    VALUES (customer_id_value, 'WVWZZZ1JZXW900002', 'ANN002', 'Test', 'Agent', 2025)
    RETURNING vehicle_id INTO vehicle_id_value;

    INSERT INTO insurance.policies(
        customer_id, vehicle_id, status, valid_from, valid_to, total_premium
    )
    VALUES (customer_id_value, vehicle_id_value, 'ACTIVE', current_date, current_date + 365, 600)
    RETURNING policy_id INTO policy_id_value;

    INSERT INTO insurance.policy_coverages(
        policy_id, coverage_code, insured_limit, deductible, premium_amount
    )
    VALUES (policy_id_value, 'OC', 5000000, 0, 600);
    SET CONSTRAINTS insurance.policies_validate_activation IMMEDIATE;
END;
$$;
ROLLBACK;

DO $$
BEGIN
    BEGIN
        INSERT INTO claims.payouts(claim_id, amount) VALUES (1, 100);
        RAISE EXCEPTION 'agent unexpectedly inserted payout';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO audit.activity_log(
            database_user, action, schema_name, table_name, record_key
        ) VALUES (session_user, 'INSERT', 'test', 'test', '{}'::jsonb);
        RAISE EXCEPTION 'agent unexpectedly modified audit';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        PERFORM count(*) FROM audit.activity_log;
        RAISE EXCEPTION 'agent unexpectedly read audit';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM insurance.customers WHERE customer_id = 1;
        RAISE EXCEPTION 'agent unexpectedly deleted business data';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$$;

SELECT current_user, session_user, 'agent permission tests: PASS' AS result;

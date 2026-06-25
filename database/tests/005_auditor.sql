\set ON_ERROR_STOP on

SELECT count(*) FROM insurance.customers;
SELECT count(*) FROM audit.activity_log;

DO $$
DECLARE
    persona_audit_count integer;
BEGIN
    SELECT count(*) INTO persona_audit_count
    FROM audit.activity_log
    WHERE database_user = 'app_agent_anna'
      AND table_name = 'customers'
      AND action = 'INSERT';
    IF persona_audit_count < 1 THEN
        RAISE EXCEPTION 'audit does not contain app_agent_anna operation';
    END IF;

    BEGIN
        UPDATE insurance.customers SET first_name = first_name WHERE customer_id = 1;
        RAISE EXCEPTION 'auditor unexpectedly updated customer';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO claims.claims(
            policy_id, vehicle_id, incident_at, description, estimated_loss
        ) VALUES (1, 1, clock_timestamp(), 'auditor forbidden test', 1);
        RAISE EXCEPTION 'auditor unexpectedly inserted claim';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE audit.activity_log SET action = action WHERE activity_id = 1;
        RAISE EXCEPTION 'auditor unexpectedly modified audit';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO audit.activity_log(
            database_user, action, schema_name, table_name, record_key
        ) VALUES (session_user, 'INSERT', 'test', 'test', '{}'::jsonb);
        RAISE EXCEPTION 'auditor unexpectedly inserted audit row';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM audit.activity_log WHERE activity_id = 1;
        RAISE EXCEPTION 'auditor unexpectedly deleted audit row';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$$;

SELECT current_user, session_user, 'auditor permission and audit tests: PASS' AS result;

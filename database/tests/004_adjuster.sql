\set ON_ERROR_STOP on

SELECT count(*) FROM insurance.policies;

BEGIN;
DO $$
DECLARE
    claim_id_value bigint;
    event_count integer;
BEGIN
    INSERT INTO claims.claims(
        policy_id, vehicle_id, incident_at, description, estimated_loss
    )
    VALUES (1, 1, clock_timestamp(), 'adjuster role test', 500)
    RETURNING claim_id INTO claim_id_value;

    INSERT INTO claims.claim_events(claim_id, event_type, note)
    VALUES (claim_id_value, 'NOTE', 'manual adjuster event');

    INSERT INTO claims.payouts(claim_id, amount, status)
    VALUES (claim_id_value, 100, 'PROPOSED');

    UPDATE claims.claims SET status = 'UNDER_REVIEW' WHERE claim_id = claim_id_value;

    SELECT count(*) INTO event_count
    FROM claims.claim_events
    WHERE claim_id = claim_id_value AND event_type = 'STATUS_CHANGED';
    IF event_count <> 1 THEN
        RAISE EXCEPTION 'adjuster status update did not create event';
    END IF;
END;
$$;
ROLLBACK;

DO $$
BEGIN
    BEGIN
        UPDATE insurance.policies SET total_premium = total_premium WHERE policy_id = 1;
        RAISE EXCEPTION 'adjuster unexpectedly updated policy';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        PERFORM count(*) FROM audit.activity_log;
        RAISE EXCEPTION 'adjuster unexpectedly read audit';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        DELETE FROM claims.claims WHERE claim_id = 1;
        RAISE EXCEPTION 'adjuster unexpectedly deleted business data';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$$;

SELECT current_user, session_user, 'adjuster permission tests: PASS' AS result;

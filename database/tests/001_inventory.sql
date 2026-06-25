\set ON_ERROR_STOP on

DO $$
DECLARE
    business_schema_count integer;
    business_table_count integer;
    public_table_count integer;
    required_index_count integer;
    group_count integer;
    login_count integer;
    membership_count integer;
    unsafe_role_count integer;
    bad_delete_privilege_count integer;
    seed_count integer;
BEGIN
    SELECT count(*) INTO business_schema_count
    FROM pg_catalog.pg_namespace
    WHERE nspname IN ('insurance', 'claims', 'audit');
    IF business_schema_count <> 3 THEN
        RAISE EXCEPTION 'expected 3 business schemas, got %', business_schema_count;
    END IF;

    SELECT count(*) INTO business_table_count
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('insurance', 'claims', 'audit')
      AND c.relkind = 'r';
    IF business_table_count <> 8 THEN
        RAISE EXCEPTION 'expected 8 business tables, got %', business_table_count;
    END IF;

    SELECT count(*) INTO public_table_count
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r';
    IF public_table_count <> 0 THEN
        RAISE EXCEPTION 'expected no public tables, got %', public_table_count;
    END IF;

    SELECT count(*) INTO required_index_count
    FROM pg_catalog.pg_indexes
    WHERE indexname IN (
        'customers_name_idx', 'vehicles_owner_idx',
        'policies_customer_status_idx', 'policies_vehicle_status_idx',
        'policies_validity_idx', 'policy_coverages_policy_idx',
        'claims_policy_idx', 'claims_vehicle_idx',
        'claims_status_reported_idx', 'claim_events_claim_created_idx',
        'payouts_claim_status_idx', 'activity_log_occurred_idx',
        'activity_log_object_idx'
    );
    IF required_index_count <> 13 THEN
        RAISE EXCEPTION 'expected 13 required indexes, got %', required_index_count;
    END IF;

    SELECT count(*) INTO group_count
    FROM pg_catalog.pg_roles
    WHERE rolname IN ('grp_agent', 'grp_claims_adjuster', 'grp_auditor')
      AND NOT rolcanlogin;
    IF group_count <> 3 THEN
        RAISE EXCEPTION 'expected 3 NOLOGIN groups, got %', group_count;
    END IF;

    SELECT count(*) INTO login_count
    FROM pg_catalog.pg_roles
    WHERE rolname IN ('app_agent_anna', 'app_adjuster_piotr', 'app_auditor_ewa')
      AND rolcanlogin;
    IF login_count <> 3 THEN
        RAISE EXCEPTION 'expected 3 LOGIN personas, got %', login_count;
    END IF;

    SELECT count(*) INTO membership_count
    FROM pg_catalog.pg_auth_members AS m
    JOIN pg_catalog.pg_roles AS parent ON parent.oid = m.roleid
    JOIN pg_catalog.pg_roles AS member ON member.oid = m.member
    WHERE (parent.rolname, member.rolname) IN (
        ('grp_agent', 'app_agent_anna'),
        ('grp_claims_adjuster', 'app_adjuster_piotr'),
        ('grp_auditor', 'app_auditor_ewa')
    );
    IF membership_count <> 3 THEN
        RAISE EXCEPTION 'expected 3 persona memberships, got %', membership_count;
    END IF;

    SELECT count(*) INTO unsafe_role_count
    FROM pg_catalog.pg_roles
    WHERE rolname IN ('app_agent_anna', 'app_adjuster_piotr', 'app_auditor_ewa')
      AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls);
    IF unsafe_role_count <> 0 THEN
        RAISE EXCEPTION 'persona has unsafe role attributes';
    END IF;

    SELECT count(*) INTO bad_delete_privilege_count
    FROM (VALUES
        ('app_agent_anna', 'insurance.customers'),
        ('app_agent_anna', 'insurance.vehicles'),
        ('app_agent_anna', 'insurance.policies'),
        ('app_agent_anna', 'insurance.policy_coverages'),
        ('app_agent_anna', 'claims.claims'),
        ('app_agent_anna', 'claims.claim_events'),
        ('app_agent_anna', 'claims.payouts'),
        ('app_adjuster_piotr', 'insurance.customers'),
        ('app_adjuster_piotr', 'insurance.vehicles'),
        ('app_adjuster_piotr', 'insurance.policies'),
        ('app_adjuster_piotr', 'insurance.policy_coverages'),
        ('app_adjuster_piotr', 'claims.claims'),
        ('app_adjuster_piotr', 'claims.claim_events'),
        ('app_adjuster_piotr', 'claims.payouts'),
        ('app_auditor_ewa', 'insurance.customers'),
        ('app_auditor_ewa', 'insurance.vehicles'),
        ('app_auditor_ewa', 'insurance.policies'),
        ('app_auditor_ewa', 'insurance.policy_coverages'),
        ('app_auditor_ewa', 'claims.claims'),
        ('app_auditor_ewa', 'claims.claim_events'),
        ('app_auditor_ewa', 'claims.payouts'),
        ('app_auditor_ewa', 'audit.activity_log')
    ) AS checked(role_name, table_name)
    WHERE pg_catalog.has_table_privilege(role_name, table_name, 'DELETE');
    IF bad_delete_privilege_count <> 0 THEN
        RAISE EXCEPTION 'persona has forbidden DELETE privilege';
    END IF;

    SELECT count(*) INTO seed_count FROM insurance.customers;
    IF seed_count <> 8 THEN RAISE EXCEPTION 'expected 8 seeded customers, got %', seed_count; END IF;
    SELECT count(*) INTO seed_count FROM insurance.vehicles;
    IF seed_count <> 10 THEN RAISE EXCEPTION 'expected 10 seeded vehicles, got %', seed_count; END IF;
    SELECT count(*) INTO seed_count FROM insurance.policies;
    IF seed_count <> 10 THEN RAISE EXCEPTION 'expected 10 seeded policies, got %', seed_count; END IF;
    SELECT count(DISTINCT coverage_code) INTO seed_count FROM insurance.policy_coverages;
    IF seed_count <> 4 THEN RAISE EXCEPTION 'expected all 4 coverage codes, got %', seed_count; END IF;
    SELECT count(*) INTO seed_count FROM claims.claims;
    IF seed_count <> 5 THEN RAISE EXCEPTION 'expected 5 seeded claims, got %', seed_count; END IF;
    SELECT count(DISTINCT claim_id) INTO seed_count FROM claims.claim_events;
    IF seed_count <> 5 THEN RAISE EXCEPTION 'expected history for 5 claims, got %', seed_count; END IF;
    SELECT count(*) INTO seed_count FROM claims.payouts;
    IF seed_count <> 2 THEN RAISE EXCEPTION 'expected 2 seeded payouts, got %', seed_count; END IF;
    SELECT count(*) INTO seed_count FROM audit.activity_log;
    IF seed_count = 0 THEN RAISE EXCEPTION 'expected audit entries created by seed'; END IF;
END;
$$;

SELECT n.nspname AS schema_name, c.relname AS table_name
FROM pg_catalog.pg_class AS c
JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname IN ('insurance', 'claims', 'audit') AND c.relkind = 'r'
ORDER BY 1, 2;

SELECT 'inventory tests: PASS' AS result;

\set ON_ERROR_STOP on

\if :{?agent_password}
\else
  DO $missing$ BEGIN
      RAISE EXCEPTION 'Missing required psql variable: agent_password';
  END $missing$;
\endif
\if :{?adjuster_password}
\else
  DO $missing$ BEGIN
      RAISE EXCEPTION 'Missing required psql variable: adjuster_password';
  END $missing$;
\endif
\if :{?auditor_password}
\else
  DO $missing$ BEGIN
      RAISE EXCEPTION 'Missing required psql variable: auditor_password';
  END $missing$;
\endif

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'grp_agent') THEN
        CREATE ROLE grp_agent NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'grp_claims_adjuster') THEN
        CREATE ROLE grp_claims_adjuster NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'grp_auditor') THEN
        CREATE ROLE grp_auditor NOLOGIN;
    END IF;
END;
$$;

ALTER ROLE grp_agent NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOINHERIT NOREPLICATION NOBYPASSRLS;
ALTER ROLE grp_claims_adjuster NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOINHERIT NOREPLICATION NOBYPASSRLS;
ALTER ROLE grp_auditor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
    NOINHERIT NOREPLICATION NOBYPASSRLS;

SELECT format(
    'CREATE ROLE app_agent_anna LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS',
    :'agent_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_agent_anna')
\gexec
SELECT format(
    'CREATE ROLE app_adjuster_piotr LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS',
    :'adjuster_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_adjuster_piotr')
\gexec
SELECT format(
    'CREATE ROLE app_auditor_ewa LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS',
    :'auditor_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_auditor_ewa')
\gexec

ALTER ROLE app_agent_anna LOGIN PASSWORD :'agent_password'
    NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
ALTER ROLE app_adjuster_piotr LOGIN PASSWORD :'adjuster_password'
    NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
ALTER ROLE app_auditor_ewa LOGIN PASSWORD :'auditor_password'
    NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;

GRANT grp_agent TO app_agent_anna;
GRANT grp_claims_adjuster TO app_adjuster_piotr;
GRANT grp_auditor TO app_auditor_ewa;

REVOKE ALL ON DATABASE vehicle_insurance FROM PUBLIC;
GRANT CONNECT ON DATABASE vehicle_insurance
    TO grp_agent, grp_claims_adjuster, grp_auditor;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

REVOKE ALL ON SCHEMA insurance, claims, audit FROM PUBLIC;
GRANT USAGE ON SCHEMA insurance, claims TO grp_agent, grp_claims_adjuster;
GRANT USAGE ON SCHEMA insurance, claims, audit TO grp_auditor;

REVOKE ALL ON ALL TABLES IN SCHEMA insurance, claims, audit FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA insurance, claims, audit FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE ON
    insurance.customers,
    insurance.vehicles,
    insurance.policies,
    insurance.policy_coverages
TO grp_agent;
GRANT SELECT ON
    claims.claims,
    claims.claim_events,
    claims.payouts,
    insurance.active_policy_summary,
    claims.open_claim_summary
TO grp_agent;

GRANT SELECT ON
    insurance.customers,
    insurance.vehicles,
    insurance.policies,
    insurance.policy_coverages,
    insurance.active_policy_summary
TO grp_claims_adjuster;
GRANT SELECT, INSERT, UPDATE ON claims.claims, claims.payouts
TO grp_claims_adjuster;
GRANT SELECT, INSERT ON claims.claim_events TO grp_claims_adjuster;
GRANT SELECT ON claims.open_claim_summary TO grp_claims_adjuster;

GRANT SELECT ON
    insurance.customers,
    insurance.vehicles,
    insurance.policies,
    insurance.policy_coverages,
    insurance.active_policy_summary,
    claims.claims,
    claims.claim_events,
    claims.payouts,
    claims.open_claim_summary,
    audit.activity_log,
    audit.recent_activity
TO grp_auditor;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA insurance TO grp_agent;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA claims TO grp_claims_adjuster;

REVOKE INSERT, UPDATE, DELETE ON audit.activity_log
FROM grp_agent, grp_claims_adjuster, grp_auditor;
REVOKE DELETE ON ALL TABLES IN SCHEMA insurance, claims, audit
FROM grp_agent, grp_claims_adjuster, grp_auditor;

ALTER DEFAULT PRIVILEGES IN SCHEMA insurance
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA insurance
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA insurance
    GRANT SELECT, INSERT, UPDATE ON TABLES TO grp_agent;
ALTER DEFAULT PRIVILEGES IN SCHEMA insurance
    GRANT SELECT ON TABLES TO grp_claims_adjuster, grp_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims
    GRANT SELECT ON TABLES TO grp_agent, grp_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
    GRANT SELECT ON TABLES TO grp_auditor;
ALTER DEFAULT PRIVILEGES IN SCHEMA insurance
    GRANT USAGE, SELECT ON SEQUENCES TO grp_agent;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims
    GRANT USAGE, SELECT ON SEQUENCES TO grp_claims_adjuster;

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO insurance.customers
    (customer_number, first_name, last_name, national_id, email, phone)
VALUES
    ('CUS-000001', 'Jan', 'Kowalski', '80010112345', 'jan.kowalski@example.test', '+48100100100'),
    ('CUS-000002', 'Maria', 'Nowak', '82020223456', 'maria.nowak@example.test', '+48200200200'),
    ('CUS-000003', 'Tomasz', 'Wiśniewski', '75030334567', 'tomasz.w@example.test', '+48300300300'),
    ('CUS-000004', 'Agnieszka', 'Wójcik', '90040445678', 'agnieszka.w@example.test', '+48400400400'),
    ('CUS-000005', 'Marek', 'Kamiński', '68050556789', 'marek.k@example.test', '+48500500500'),
    ('CUS-000006', 'Katarzyna', 'Lewandowska', '95060667890', 'katarzyna.l@example.test', '+48600600600'),
    ('CUS-000007', 'Paweł', 'Zieliński', '87070778901', 'pawel.z@example.test', '+48700700700'),
    ('CUS-000008', 'Ewa', 'Szymańska', '79080889012', 'ewa.s@example.test', '+48800800800');

INSERT INTO insurance.vehicles
    (owner_customer_id, vin, registration_number, make, model, production_year)
VALUES
    (1, 'WVWZZZ1JZXW000001', 'WA1001A', 'Volkswagen', 'Golf', 2018),
    (1, 'TMBJJ7NE0J0000002', 'WA1002A', 'Skoda', 'Octavia', 2019),
    (2, 'VF1RFB00600000003', 'KR2001K', 'Renault', 'Megane', 2020),
    (3, 'WBA8E11000K000004', 'PO3001P', 'BMW', '320i', 2017),
    (4, 'JTDKB20U000000005', 'GD4001G', 'Toyota', 'Corolla', 2021),
    (5, 'KMHCT41D000000006', 'LU5001L', 'Hyundai', 'i30', 2016),
    (6, 'WF0FXXWPCF0000007', 'WR6001W', 'Ford', 'Focus', 2019),
    (7, 'ZFA31200000000008', 'BI7001B', 'Fiat', '500', 2015),
    (8, 'YS3FD79Y000000009', 'SZ8001S', 'Saab', '9-3', 2011),
    (2, 'WAUZZZ8V000000010', 'KR2002K', 'Audi', 'A3', 2022);

INSERT INTO insurance.policies
    (policy_number, customer_id, vehicle_id, status, valid_from, valid_to, total_premium, created_by)
VALUES
    ('POL-2026-000001', 1, 1, 'DRAFT', '2026-01-01', '2026-12-31', 1450.00, 'seed'),
    ('POL-2026-000002', 1, 2, 'DRAFT', '2026-02-01', '2027-01-31', 1200.00, 'seed'),
    ('POL-2026-000003', 2, 3, 'DRAFT', '2026-03-01', '2027-02-28', 1650.00, 'seed'),
    ('POL-2026-000004', 3, 4, 'DRAFT', '2026-01-15', '2027-01-14', 2400.00, 'seed'),
    ('POL-2026-000005', 4, 5, 'DRAFT', '2026-04-01', '2027-03-31', 1350.00, 'seed'),
    ('POL-2026-000006', 5, 6, 'DRAFT', '2025-01-01', '2025-12-31', 980.00, 'seed'),
    ('POL-2026-000007', 6, 7, 'DRAFT', '2026-05-01', '2027-04-30', 1510.00, 'seed'),
    ('POL-2026-000008', 7, 8, 'DRAFT', '2026-06-01', '2027-05-31', 890.00, 'seed'),
    ('POL-2026-000009', 8, 9, 'DRAFT', '2025-06-01', '2026-05-31', 1100.00, 'seed'),
    ('POL-2026-000010', 2, 10, 'DRAFT', '2026-06-15', '2027-06-14', 2100.00, 'seed');

INSERT INTO insurance.policy_coverages
    (policy_id, coverage_code, insured_limit, deductible, premium_amount)
VALUES
    (1, 'OC', 5000000, 0, 700), (1, 'AC', 60000, 1000, 750),
    (2, 'OC', 5000000, 0, 800), (2, 'ASSISTANCE', 10000, 0, 400),
    (3, 'OC', 5000000, 0, 850), (3, 'NNW', 50000, 0, 800),
    (4, 'OC', 5000000, 0, 900), (4, 'AC', 110000, 1500, 1500),
    (5, 'OC', 5000000, 0, 750), (5, 'ASSISTANCE', 15000, 0, 600),
    (6, 'OC', 5000000, 0, 980),
    (7, 'OC', 5000000, 0, 810), (7, 'NNW', 75000, 0, 700),
    (8, 'OC', 5000000, 0, 650), (8, 'ASSISTANCE', 8000, 0, 240),
    (9, 'OC', 5000000, 0, 1100),
    (10, 'OC', 5000000, 0, 900), (10, 'AC', 130000, 2000, 1200);

UPDATE insurance.policies SET status = 'ACTIVE' WHERE policy_id IN (1, 2, 3, 4, 5, 7, 8, 10);
UPDATE insurance.policies SET status = 'EXPIRED' WHERE policy_id = 6;
UPDATE insurance.policies SET status = 'SUSPENDED' WHERE policy_id = 9;

INSERT INTO claims.claims
    (claim_number, policy_id, vehicle_id, status, incident_at, reported_at,
     description, estimated_loss, assigned_adjuster)
VALUES
    ('CLM-2026-000001', 1, 1, 'REPORTED', '2026-05-10 10:00+02', '2026-05-10 12:00+02', 'Kolizja parkingowa', 3500, 'app_adjuster_piotr'),
    ('CLM-2026-000002', 3, 3, 'UNDER_REVIEW', '2026-05-18 17:30+02', '2026-05-19 08:00+02', 'Uszkodzenie przodu pojazdu', 18000, 'app_adjuster_piotr'),
    ('CLM-2026-000003', 4, 4, 'APPROVED', '2026-04-02 09:00+02', '2026-04-02 10:00+02', 'Szkoda szybowa', 4200, 'app_adjuster_piotr'),
    ('CLM-2026-000004', 5, 5, 'REJECTED', '2026-03-12 20:00+01', '2026-03-13 09:00+01', 'Zdarzenie poza zakresem', 1200, 'app_adjuster_piotr'),
    ('CLM-2026-000005', 7, 7, 'CLOSED', '2026-02-01 14:00+01', '2026-02-01 15:00+01', 'Stłuczka drogowa', 7600, 'app_adjuster_piotr');

INSERT INTO claims.claim_events (claim_id, event_type, note, created_by)
VALUES
    (1, 'REPORTED', 'Przyjęto zgłoszenie', 'seed'),
    (2, 'REPORTED', 'Przyjęto zgłoszenie', 'seed'),
    (2, 'DOCUMENT_RECEIVED', 'Otrzymano zdjęcia', 'seed'),
    (3, 'REPORTED', 'Przyjęto zgłoszenie', 'seed'),
    (3, 'DECISION', 'Szkoda zaakceptowana', 'seed'),
    (4, 'REPORTED', 'Przyjęto zgłoszenie', 'seed'),
    (4, 'DECISION', 'Brak ochrony dla zdarzenia', 'seed'),
    (5, 'REPORTED', 'Przyjęto zgłoszenie', 'seed'),
    (5, 'DECISION', 'Szkoda rozliczona', 'seed');

INSERT INTO claims.payouts
    (claim_id, amount, status, approved_by, approved_at, paid_at)
VALUES
    (3, 4200, 'APPROVED', 'app_adjuster_piotr', '2026-04-05 10:00+02', NULL),
    (5, 7300, 'PAID', 'app_adjuster_piotr', '2026-02-05 10:00+01', '2026-02-06 12:00+01');

SELECT setval('insurance.customer_number_seq', 1008, true);
SELECT setval('insurance.policy_number_seq', 1010, true);
SELECT setval('claims.claim_number_seq', 1005, true);

COMMIT;

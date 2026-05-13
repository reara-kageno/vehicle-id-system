DROP DATABASE IF EXISTS "plateiq-db";

-- Users (system access table)
CREATE TABLE Users (
    user_id     SERIAL          PRIMARY KEY,
    username    VARCHAR(50)     NOT NULL UNIQUE,
    password    VARCHAR(255)    NOT NULL,
    role        VARCHAR(20)     NOT NULL CHECK (role IN ('ADMIN','CUSTOMER','WORKSHOP','INSURANCE','POLICE')),
    status      VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
    created_at  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

-- Customer
CREATE TABLE Customer (
    customer_id SERIAL          PRIMARY KEY,
    name        VARCHAR(100)    NOT NULL,
    address     TEXT,
    phone       VARCHAR(20),
    email       VARCHAR(100)
);

--Vehicle
CREATE TABLE Vehicle (
    vehicle_id          SERIAL          PRIMARY KEY,
    registration_number VARCHAR(20)     NOT NULL UNIQUE,
    make                VARCHAR(50)     NOT NULL,
    model               VARCHAR(50)     NOT NULL,
    year                INT             NOT NULL CHECK (year BETWEEN 1990 AND 2100),
    color               VARCHAR(30),
    owner_id            INT             REFERENCES Customer(customer_id) ON DELETE SET NULL
);

--ServiceRecord
CREATE TABLE ServiceRecord (
    service_id      SERIAL          PRIMARY KEY,
    vehicle_id      INT             NOT NULL REFERENCES Vehicle(vehicle_id) ON DELETE CASCADE,
    service_date    DATE            NOT NULL,
    service_type    VARCHAR(100)    NOT NULL,
    description     TEXT,
    cost            DECIMAL(10,2)   NOT NULL DEFAULT 0.00
);

--CustomerQuery
CREATE TABLE CustomerQuery (
    query_id        SERIAL      PRIMARY KEY,
    customer_id     INT         NOT NULL REFERENCES Customer(customer_id) ON DELETE CASCADE,
    vehicle_id      INT         NOT NULL REFERENCES Vehicle(vehicle_id) ON DELETE CASCADE,
    query_date      DATE        NOT NULL DEFAULT CURRENT_DATE,
    query_text      TEXT        NOT NULL,
    response_text   TEXT
);

--InsurancePolicy
CREATE TABLE InsurancePolicy (
    policy_id           SERIAL          PRIMARY KEY,
    vehicle_id          INT             NOT NULL REFERENCES Vehicle(vehicle_id) ON DELETE CASCADE,
    insurance_company   VARCHAR(100)    NOT NULL,
    policy_number       VARCHAR(50)     NOT NULL UNIQUE,
    start_date          DATE            NOT NULL,
    end_date            DATE            NOT NULL,
    coverage_details    TEXT
);

-- Claim
CREATE TABLE Claim (
    claim_id        SERIAL          PRIMARY KEY,
    policy_id       INT             NOT NULL REFERENCES InsurancePolicy(policy_id) ON DELETE CASCADE,
    claim_date      DATE            NOT NULL,
    claim_amount    DECIMAL(10,2)   NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING','APPROVED','REJECTED'))
);

--PoliceReport
CREATE TABLE PoliceReport (
    report_id       SERIAL          PRIMARY KEY,
    vehicle_id      INT             NOT NULL REFERENCES Vehicle(vehicle_id) ON DELETE CASCADE,
    report_date     DATE            NOT NULL,
    report_type     VARCHAR(50)     NOT NULL CHECK (report_type IN ('THEFT','ACCIDENT','INSPECTION','OTHER')),
    description     TEXT,
    officer_name    VARCHAR(100)    NOT NULL
);

--Violation
CREATE TABLE Violation (
    violation_id    SERIAL          PRIMARY KEY,
    vehicle_id      INT             NOT NULL REFERENCES Vehicle(vehicle_id) ON DELETE CASCADE,
    violation_date  DATE            NOT NULL,
    violation_type  VARCHAR(100)    NOT NULL,
    fine_amount     DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    status          VARCHAR(20)     NOT NULL DEFAULT 'UNPAID' CHECK (status IN ('PAID','UNPAID'))
);

--Full vehicle details: vehicle + owner + active insurance
CREATE OR REPLACE VIEW vehicle_full_details AS
SELECT
    v.vehicle_id,
    v.registration_number,
    v.make,
    v.model,
    v.year,
    v.color,
    c.customer_id,
    c.name          AS owner_name,
    c.phone         AS owner_phone,
    c.email         AS owner_email,
    c.address       AS owner_address,
    ip.policy_id,
    ip.insurance_company,
    ip.policy_number,
    ip.start_date   AS policy_start,
    ip.end_date     AS policy_end,
    CASE
        WHEN ip.end_date >= CURRENT_DATE THEN 'ACTIVE'
        WHEN ip.end_date IS NULL         THEN 'NO POLICY'
        ELSE                                  'EXPIRED'
    END             AS insurance_status
FROM Vehicle v
LEFT JOIN Customer c        ON v.owner_id   = c.customer_id
LEFT JOIN InsurancePolicy ip ON v.vehicle_id = ip.vehicle_id;

-- All unpaid violations with vehicle and owner info
CREATE OR REPLACE VIEW unpaid_violations AS
SELECT
    vl.violation_id,
    vl.violation_date,
    vl.violation_type,
    vl.fine_amount,
    vl.status,
    v.registration_number,
    v.make,
    v.model,
    c.name  AS owner_name,
    c.phone AS owner_phone
FROM Violation vl
JOIN Vehicle  v ON vl.vehicle_id = v.vehicle_id
LEFT JOIN Customer c ON v.owner_id = c.customer_id
WHERE vl.status = 'UNPAID'
ORDER BY vl.violation_date DESC;

-- 3.3 Vehicle service summary
CREATE OR REPLACE VIEW vehicle_service_summary AS
SELECT
    v.vehicle_id,
    v.registration_number,
    v.make,
    v.model,
    COUNT(sr.service_id)        AS total_services,
    MAX(sr.service_date)        AS last_service_date,
    SUM(sr.cost)                AS total_service_cost
FROM Vehicle v
LEFT JOIN ServiceRecord sr ON v.vehicle_id = sr.vehicle_id
GROUP BY v.vehicle_id, v.registration_number, v.make, v.model;

-- 3.4 Insurance policies expiring within 60 days
CREATE OR REPLACE VIEW expiring_policies AS
SELECT
    ip.policy_id,
    ip.policy_number,
    ip.insurance_company,
    ip.end_date,
    (ip.end_date - CURRENT_DATE) AS days_remaining,
    v.registration_number,
    v.make,
    v.model,
    c.name  AS owner_name,
    c.phone AS owner_phone
FROM InsurancePolicy ip
JOIN Vehicle  v ON ip.vehicle_id = v.vehicle_id
LEFT JOIN Customer c ON v.owner_id  = c.customer_id
WHERE ip.end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '60 days')
ORDER BY ip.end_date ASC;

--Register a new vehicle and link to an existing customer
CREATE OR REPLACE PROCEDURE register_vehicle(
    p_registration_number   VARCHAR(20),
    p_make                  VARCHAR(50),
    p_model                 VARCHAR(50),
    p_year                  INT,
    p_color                 VARCHAR(30),
    p_owner_id              INT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Vehicle WHERE registration_number = p_registration_number) THEN
        RAISE EXCEPTION 'Vehicle with registration % already exists.', p_registration_number;
    END IF;

    INSERT INTO Vehicle (registration_number, make, model, year, color, owner_id)
    VALUES (p_registration_number, p_make, p_model, p_year, p_color, p_owner_id);

    RAISE NOTICE 'Vehicle % registered successfully.', p_registration_number;
END;
$$;

--Add a service record for a vehicle
CREATE OR REPLACE PROCEDURE add_service_record(
    p_vehicle_id    INT,
    p_service_date  DATE,
    p_service_type  VARCHAR(100),
    p_description   TEXT,
    p_cost          DECIMAL(10,2)
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Vehicle WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle with ID % does not exist.', p_vehicle_id;
    END IF;

    INSERT INTO ServiceRecord (vehicle_id, service_date, service_type, description, cost)
    VALUES (p_vehicle_id, p_service_date, p_service_type, p_description, p_cost);

    RAISE NOTICE 'Service record added for vehicle ID %.', p_vehicle_id;
END;
$$;

--Add a police report for a vehicle
CREATE OR REPLACE PROCEDURE add_police_report(
    p_vehicle_id    INT,
    p_report_date   DATE,
    p_report_type   VARCHAR(50),
    p_description   TEXT,
    p_officer_name  VARCHAR(100)
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Vehicle WHERE vehicle_id = p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle with ID % does not exist.', p_vehicle_id;
    END IF;

    INSERT INTO PoliceReport (vehicle_id, report_date, report_type, description, officer_name)
    VALUES (p_vehicle_id, p_report_date, p_report_type, p_description, p_officer_name);

    RAISE NOTICE 'Police report added for vehicle ID %.', p_vehicle_id;
END;
$$;

--Process an insurance claim
CREATE OR REPLACE PROCEDURE process_claim(
    p_policy_id     INT,
    p_claim_date    DATE,
    p_claim_amount  DECIMAL(10,2),
    p_status        VARCHAR(20) DEFAULT 'PENDING'
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM InsurancePolicy WHERE policy_id = p_policy_id) THEN
        RAISE EXCEPTION 'Policy with ID % does not exist.', p_policy_id;
    END IF;

    INSERT INTO Claim (policy_id, claim_date, claim_amount, status)
    VALUES (p_policy_id, p_claim_date, p_claim_amount, p_status);

    RAISE NOTICE 'Claim submitted for policy ID %.', p_policy_id;
END;
$$;

--Update violation payment status
CREATE OR REPLACE PROCEDURE pay_violation(
    p_violation_id INT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Violation WHERE violation_id = p_violation_id) THEN
        RAISE EXCEPTION 'Violation with ID % does not exist.', p_violation_id;
    END IF;

    UPDATE Violation SET status = 'PAID' WHERE violation_id = p_violation_id;
    RAISE NOTICE 'Violation % marked as PAID.', p_violation_id;
END;
$$;

INSERT INTO Users (username, password, role, status) VALUES
('admin.mokoena',    'hashed_Admin@123',     'ADMIN',     'ACTIVE'),
('admin.ntoi',       'hashed_Admin@456',     'ADMIN',     'ACTIVE'),
('thabo.letsie',     'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('palesa.mosotho',   'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('rethabile.khali',  'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('lineo.mafoso',     'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('mpho.sekoati',     'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('teboho.ramoeli',   'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('mamello.nkosi',    'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('lerato.tau',       'hashed_User@1234',     'CUSTOMER',  'ACTIVE'),
('workshop.maseru',  'hashed_Work@1234',     'WORKSHOP',  'ACTIVE'),
('workshop.leribe',  'hashed_Work@1234',     'WORKSHOP',  'ACTIVE'),
('ins.lesotho',      'hashed_Ins@1234',      'INSURANCE', 'ACTIVE'),
('ins.continental',  'hashed_Ins@1234',      'INSURANCE', 'ACTIVE'),
('sgt.mohlomi',      'hashed_Pol@1234',      'POLICE',    'ACTIVE'),
('const.tlali',      'hashed_Pol@1234',      'POLICE',    'ACTIVE'),
('const.molefi',     'hashed_Pol@1234',      'POLICE',    'ACTIVE'),
('inactive.user',    'hashed_User@1234',     'CUSTOMER',  'INACTIVE');

--Customers
INSERT INTO Customer (name, address, phone, email) VALUES
('Thabo Letsie',        'Ha Abia, Maseru 100',              '+26657812345',  'thabo.letsie@gmail.com'),
('Palesa Mosotho',      'Teyateyaneng, Berea 200',          '+26658923456',  'palesa.m@yahoo.com'),
('Rethabile Khali',     'Leribe Town, Leribe 300',          '+26659034567',  'rethabile.k@outlook.com'),
('Lineo Mafoso',        'Mohales Hoek, MH 400',           '+26657145678',  'lineo.mafoso@gmail.com'),
('Mpho Sekoati',        'Qachas Nek, QN 500',             '+26658256789',  'mpho.sekoati@gmail.com'),
('Teboho Ramoeli',      'Butha-Buthe Town, BB 600',         '+26659367890',  'teboho.r@gmail.com'),
('Mamello Nkosi',       'Mafeteng Central, Mafeteng 700',   '+26657478901',  'mamello.nkosi@yahoo.com'),
('Lerato Tau',          'Ha Thetsane, Maseru 105',          '+26658589012',  'lerato.tau@gmail.com'),
('Nthabiseng Peete',    'Maputsoe, Leribe 310',             '+26659690123',  'nthabiseng.p@gmail.com'),
('Lebohang Mofolo',     'Roma Campus Area, Maseru 180',     '+26657701234',  'lebohang.mofolo@lu.ac.ls');

--Vehicles
INSERT INTO Vehicle (registration_number, make, model, year, color, owner_id) VALUES
('LS-1042-AA',  'Toyota',       'Corolla',          2018,  'Silver',      1),
('LS-2387-BB',  'Toyota',       'Hilux',            2020,  'White',       2),
('LS-3901-CC',  'Volkswagen',   'Polo Vivo',        2019,  'Black',       3),
('LS-4455-DD',  'Ford',         'Ranger',           2021,  'Blue',        4),
('LS-5512-EE',  'Toyota',       'Land Cruiser',     2017,  'Grey',        5),
('LS-6623-FF',  'Hyundai',      'Tucson',           2022,  'White',       6),
('LS-7734-GG',  'Nissan',       'NP200',            2016,  'Red',         7),
('LS-8845-HH',  'Mazda',        'CX-5',             2023,  'Pearl White', 8),
('LS-9956-II',  'Isuzu',        'D-Max',            2019,  'Orange',      9),
('LS-0167-JJ',  'BMW',          '3 Series',         2020,  'Black',       10),
('LS-1278-KK',  'Suzuki',       'Swift',            2021,  'Blue',        1),
('LS-2389-LL',  'Mitsubishi',   'Pajero',           2015,  'Silver',      2),
('LS-3490-MM',  'Toyota',       'Fortuner',         2022,  'Dark Grey',   3),
('LS-4501-NN',  'Volkswagen',   'Amarok',           2018,  'White',       4),
('LS-5612-OO',  'Kia',          'Sportage',         2023,  'Red',         5);

--Service Records
INSERT INTO ServiceRecord (vehicle_id, service_date, service_type, description, cost) VALUES
(1,  '2024-01-15', 'Oil Change',           'Full synthetic oil change, filter replaced.',                          350.00),
(1,  '2024-06-10', 'Brake Service',        'Front brake pads and rotors replaced.',                                1200.00),
(2,  '2024-02-20', 'Scheduled Service',    '30 000 km service — oil, filters, spark plugs.',                       2800.00),
(2,  '2024-08-05', 'Tyre Rotation',        'All four tyres rotated and balanced.',                                 450.00),
(3,  '2023-11-30', 'Transmission Service', 'Transmission fluid flush and filter replacement.',                     1800.00),
(3,  '2024-03-18', 'Electrical Repair',    'Alternator replaced; battery terminals cleaned.',                      2400.00),
(4,  '2024-04-22', 'Suspension Work',      'Rear leaf springs and shock absorbers replaced.',                      3200.00),
(5,  '2023-09-14', 'Engine Tune-Up',       'Spark plugs, air filter, fuel filter replaced.',                       1600.00),
(5,  '2024-07-01', 'Cooling System',       'Radiator flushed, thermostat and hoses replaced.',                     2100.00),
(6,  '2024-05-17', 'Oil Change',           'Semi-synthetic oil change with filter.',                               380.00),
(7,  '2024-01-28', 'Brake Service',        'All four brake pads replaced. Rear drums resurfaced.',                 1500.00),
(8,  '2024-03-05', 'Scheduled Service',    '15 000 km service — first major service completed.',                   1900.00),
(9,  '2023-12-10', 'Clutch Replacement',   'Clutch plate, pressure plate, and release bearing replaced.',          4500.00),
(10, '2024-06-25', 'AC Regas',             'Air conditioning recharged. Compressor belt replaced.',                900.00),
(11, '2024-02-14', 'Wheel Alignment',      'Four-wheel alignment and balancing performed.',                        350.00),
(12, '2024-09-03', 'Oil Change',           'Full oil change — high mileage synthetic blend.',                      420.00),
(13, '2024-07-19', 'Scheduled Service',    '20 000 km service — comprehensive inspection passed.',                 2200.00),
(14, '2023-10-22', 'Electrical Fault',     'Faulty wiring in dashboard cluster diagnosed and repaired.',           1750.00),
(15, '2024-08-30', 'Tyre Replacement',     'Two front tyres replaced — Bridgestone Turanza T005.',                 2600.00),
(1,  '2025-01-10', 'Annual Service',       '60 000 km service — timing belt and water pump replaced.',             5500.00),
(3,  '2025-02-22', 'Oil Change',           'Routine oil and filter change.',                                       350.00),
(6,  '2025-03-15', 'Brake Fluid',          'Brake fluid flushed and replaced.',                                    280.00);

--Customer Queries
INSERT INTO CustomerQuery (customer_id, vehicle_id, query_date, query_text, response_text) VALUES
(1,  1,  '2024-06-12', 'When is my next scheduled service due?',
                        'Your next service is due at 70 000 km or January 2026, whichever comes first.'),
(2,  2,  '2024-08-07', 'Can you confirm my brake service was completed?',
                        'Yes, your rear brake pads were serviced on 05 August 2024.'),
(3,  3,  '2024-04-01', 'My car makes a grinding noise when turning left. What could it be?',
                        'This could be a worn CV joint. Please bring the vehicle in for inspection.'),
(4,  4,  '2024-05-20', 'I want to know the full service history before I sell the vehicle.',
                        'Your vehicle has 3 service records. We can print a full report for you.'),
(5,  5,  '2024-09-15', 'Is the engine oil still good after 8 months?',
                        'Depending on mileage — if you have done over 10 000 km, an oil change is advised.'),
(6,  6,  '2024-06-03', 'Who do I contact about adding a tow bar?',
                        'We can fit a tow bar. Please book an appointment at your nearest workshop.'),
(7,  7,  '2024-02-10', 'My check engine light came on. Is it serious?',
                        NULL),
(8,  8,  '2024-04-18', 'Can I get a quote for replacing both front tyres?',
                        'Front tyre replacement (Bridgestone) is estimated at M 2 600.00 for two.'),
(9,  9,  '2024-01-05', 'The clutch feels stiff. Is that normal after replacement?',
                        'Some stiffness is normal in the first 500 km after a new clutch. It will ease.'),
(10, 10, '2024-07-30', 'Is the AC system under warranty after the regas?',
                        'Yes, the regas service carries a 6-month warranty from the date of service.');

--Insurance Policies
INSERT INTO InsurancePolicy (vehicle_id, insurance_company, policy_number, start_date, end_date, coverage_details) VALUES
(1,  'Lesotho National Insurance',  'LNI-2024-10042',  '2024-01-01', '2025-12-31', 'Comprehensive — third party, theft, fire, accidental damage. Excess: M 2 000.'),
(2,  'Metropolitan Lesotho',        'MET-2023-20387',  '2023-06-01', '2025-05-31', 'Comprehensive — all risks including roadside assist and car hire.'),
(3,  'Old Mutual Lesotho',          'OML-2024-30901',  '2024-03-15', '2025-03-14', 'Third party only — liability cover up to M 500 000.'),
(4,  'Lesotho National Insurance',  'LNI-2023-44551',  '2023-11-01', '2024-10-31', 'Comprehensive — expired. Renewal pending.'),
(5,  'Continental Insurance',       'CON-2024-55120',  '2024-07-01', '2025-06-30', 'Comprehensive — includes off-road and flood damage cover.'),
(6,  'Metropolitan Lesotho',        'MET-2024-66230',  '2024-01-15', '2026-01-14', 'Comprehensive — new vehicle plan, zero excess first claim.'),
(7,  'Old Mutual Lesotho',          'OML-2022-77340',  '2022-08-01', '2024-07-31', 'Third party fire and theft — expired.'),
(8,  'Lesotho National Insurance',  'LNI-2024-88450',  '2024-04-01', '2026-03-31', 'Comprehensive — includes windscreen and personal accident.'),
(9,  'Continental Insurance',       'CON-2023-99560',  '2023-09-01', '2025-08-31', 'Comprehensive — commercial use endorsement included.'),
(10, 'Metropolitan Lesotho',        'MET-2024-01670',  '2024-06-20', '2026-06-19', 'Comprehensive — premium plan with courtesy car allowance.'),
(11, 'Lesotho National Insurance',  'LNI-2025-12780',  '2025-01-01', '2025-07-31', 'Third party only — budget policy, minimum legal cover.'),
(12, 'Old Mutual Lesotho',          'OML-2024-23890',  '2024-05-10', '2025-05-09', 'Comprehensive — high mileage commercial vehicle plan.'),
(13, 'Continental Insurance',       'CON-2024-34900',  '2024-08-01', '2026-07-31', 'Comprehensive — full cover, includes fleet management tools.'),
(14, 'Metropolitan Lesotho',        'MET-2023-45010',  '2023-03-01', '2024-02-28', 'Third party fire and theft — expired.'),
(15, 'Lesotho National Insurance',  'LNI-2025-56120',  '2025-02-01', '2026-01-31', 'Comprehensive — SUV plan with tracker device fitted.');

--Claims
INSERT INTO Claim (policy_id, claim_date, claim_amount, status) VALUES
(1,  '2024-03-10', 8500.00,   'APPROVED'),
(2,  '2024-07-22', 15000.00,  'PENDING'),
(3,  '2024-04-05', 3000.00,   'REJECTED'),
(5,  '2024-08-14', 22000.00,  'APPROVED'),
(6,  '2024-09-01', 5000.00,   'PENDING'),
(8,  '2024-05-19', 1200.00,   'APPROVED'),
(9,  '2023-12-30', 45000.00,  'APPROVED'),
(10, '2024-07-11', 9800.00,   'PENDING'),
(12, '2024-06-03', 3500.00,   'REJECTED'),
(13, '2024-09-25', 11000.00,  'PENDING');

--Police Reports
INSERT INTO PoliceReport (vehicle_id, report_date, report_type, description, officer_name) VALUES
(4,  '2024-03-15', 'ACCIDENT',    'Rear-end collision on Main North Road, Maseru. Minor damage to bumper. Other vehicle fled the scene.',                           'Sgt. Mohlomi Ramakatane'),
(7,  '2024-01-20', 'THEFT',       'Vehicle reported stolen from Ha Thetsane parking lot. Steering lock was broken. CCTV footage obtained.',                        'Const. Tlali Sehlabo'),
(9,  '2024-05-06', 'ACCIDENT',    'Head-on collision near Maputsoe bridge. Driver sustained injuries. Vehicle towed to Leribe workshop.',                          'Const. Molefi Liphoto'),
(5,  '2023-10-11', 'THEFT',       'Catalytic converter stolen while vehicle was parked overnight in Butha-Buthe.',                                                 'Sgt. Mohlomi Ramakatane'),
(12, '2024-02-28', 'ACCIDENT',    'Side-swipe incident in Teyateyaneng roundabout. Disputed fault. Both parties have insurance.',                                  'Const. Tlali Sehlabo'),
(3,  '2024-06-30', 'INSPECTION',  'Routine road-block inspection. Vehicle passed all checks. Licence disc valid.',                                                 'Const. Molefi Liphoto'),
(14, '2023-12-05', 'THEFT',       'Vehicle was carjacked at gunpoint on Mountain Road, Maseru. Suspects unknown. Case referred to CID.',                          'Sgt. Mohlomi Ramakatane'),
(1,  '2024-08-18', 'ACCIDENT',    'Minor fender bender in Maseru Mall parking lot. No injuries. Driver exchanged details with third party.',                      'Const. Tlali Sehlabo'),
(10, '2024-04-09', 'INSPECTION',  'Vehicle flagged for expired licence disc during road-block. Driver warned and issued compliance notice.',                       'Const. Molefi Liphoto'),
(13, '2024-09-12', 'OTHER',       'Vehicle used in suspected smuggling operation near Ficksburg border post. Referred to border control unit.',                   'Sgt. Mohlomi Ramakatane');

--Violations
INSERT INTO Violation (vehicle_id, violation_date, violation_type, fine_amount, status) VALUES
(1,  '2024-02-10', 'Speeding — 30 km/h over limit',     800.00,   'PAID'),
(3,  '2024-04-15', 'Expired licence disc',               500.00,   'UNPAID'),
(5,  '2023-11-05', 'Failure to stop at stop sign',       350.00,   'PAID'),
(7,  '2024-01-22', 'No valid roadworthy certificate',    1200.00,  'UNPAID'),
(9,  '2024-05-08', 'Overloaded vehicle',                 2000.00,  'UNPAID'),
(10, '2024-04-10', 'Expired licence disc',               500.00,   'UNPAID'),
(12, '2024-03-01', 'Illegal parking — yellow lines',     250.00,   'PAID'),
(4,  '2024-03-16', 'Failure to produce insurance disc',  600.00,   'UNPAID'),
(14, '2023-12-06', 'Driving without a licence',          3000.00,  'UNPAID'),
(2,  '2024-07-14', 'Using mobile phone while driving',   700.00,   'PAID'),
(6,  '2024-06-25', 'Speeding — 15 km/h over limit',     500.00,   'PAID'),
(8,  '2024-08-20', 'Failure to wear seatbelt',          200.00,   'UNPAID'),
(11, '2025-01-15', 'Expired licence disc',               500.00,   'UNPAID'),
(13, '2024-09-13', 'Overloaded vehicle',                 2000.00,  'UNPAID'),
(15, '2025-02-05', 'Using mobile phone while driving',   700.00,   'UNPAID');


--Count rows per table
SELECT 'Users'          AS tbl, COUNT(*) FROM Users
UNION ALL
SELECT 'Customer',             COUNT(*) FROM Customer
UNION ALL
SELECT 'Vehicle',              COUNT(*) FROM Vehicle
UNION ALL
SELECT 'ServiceRecord',        COUNT(*) FROM ServiceRecord
UNION ALL
SELECT 'CustomerQuery',        COUNT(*) FROM CustomerQuery
UNION ALL
SELECT 'InsurancePolicy',      COUNT(*) FROM InsurancePolicy
UNION ALL
SELECT 'Claim',                COUNT(*) FROM Claim
UNION ALL
SELECT 'PoliceReport',         COUNT(*) FROM PoliceReport
UNION ALL
SELECT 'Violation',            COUNT(*) FROM Violation;

--Preview views
SELECT * FROM vehicle_full_details      LIMIT 5;
SELECT * FROM unpaid_violations         LIMIT 5;
SELECT * FROM vehicle_service_summary   LIMIT 5;
SELECT * FROM expiring_policies;

--Test a stored procedure call
CALL register_vehicle('LS-9999-ZZ', 'Honda', 'Fit', 2022, 'Green', 1);
CALL add_service_record(1, CURRENT_DATE, 'Oil Change', 'Test record from procedure.', 350.00);

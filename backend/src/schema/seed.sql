-- 1. Insert Sample LGU
INSERT INTO lgus (id, lgu_code, municipality_name, province, region)
VALUES ('11111111-1111-1111-1111-111111111111', 'MKT', 'Makati City', NULL, 'NCR');

-- 2. Insert Sample Users (Password comment: use bcrypt hash in real app)
INSERT INTO users (id, email, password_hash, role) VALUES
('22222222-2222-2222-2222-222222222221', 'admin@makati.gov.ph', '$2b$10$MockHashForTestingOnly123456789012', 'LGU_ADMIN'),
('22222222-2222-2222-2222-222222222222', 'juan.pwd@email.com', '$2b$10$MockHashForTestingOnly123456789012', 'CARDHOLDER'),
('22222222-2222-2222-2222-222222222223', 'maria.senior@email.com', '$2b$10$MockHashForTestingOnly123456789012', 'CARDHOLDER'),
('22222222-2222-2222-2222-222222222224', 'cashier@mercury-mkt.com', '$2b$10$MockHashForTestingOnly123456789012', 'BUSINESS');

-- 3. Insert LGU Admin Profile
INSERT INTO lgu_admins (id, user_id, lgu_id, first_name, last_name, department, position)
VALUES (
    '33333333-3333-3333-3333-333333333331',
    '22222222-2222-2222-2222-222222222221',
    '11111111-1111-1111-1111-111111111111',
    'Roberto', 'Reyes', 'PDAO / OSCA', 'Records Officer'
);

-- 4. Insert Cardholder Profiles (1 Active PWD, 1 Active Senior Citizen)
INSERT INTO cardholder_profiles (
    id, user_id, lgu_id, issued_by_admin_id, lgu_id_number,
    first_name, middle_name, last_name, date_of_birth, sex, address,
    contact_number, privilege_type, disability_type, status,
    qr_secret_token, issued_date, expiry_date
) VALUES
(
    '44444444-4444-4444-4444-444444444441',
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    '33333333-3333-3333-3333-333333333331',
    'MKT-PWD-2026-00481',
    'Juan', 'Santos', 'Dela Cruz', '1998-05-14', 'Male', '123 Ayala Ave, Makati City',
    '+639171234567', 'PWD', 'Visual Impairment', 'ACTIVE',
    'KILALA-QR-MKT-PWD-00481-SECRET', CURRENT_DATE, CURRENT_DATE + INTERVAL '3 years'
),
(
    '44444444-4444-4444-4444-444444444442',
    '22222222-2222-2222-2222-222222222223',
    '11111111-1111-1111-1111-111111111111',
    '33333333-3333-3333-3333-333333333331',
    'MKT-OSCA-2026-08912',
    'Maria', 'Clara', 'Bautista', '1958-11-02', 'Female', '45 Poblacion, Makati City',
    '+639187654321', 'SENIOR_CITIZEN', NULL, 'ACTIVE',
    'KILALA-QR-MKT-OSCA-08912-SECRET', CURRENT_DATE, NULL
);

-- 5. Insert Business Profile
INSERT INTO business_profiles (
    id, user_id, lgu_id, business_name, branch_name, category,
    business_permit_no, tin_number, address
) VALUES (
    '55555555-5555-5555-5555-555555555551',
    '22222222-2222-2222-2222-222222222224',
    '11111111-1111-1111-1111-111111111111',
    'Mercury Drug', 'Glorietta 4 Branch', 'PHARMACY',
    'MKT-BP-2026-99102', '000-123-456-001', 'Glorietta 4, Ayala Center, Makati City'
);

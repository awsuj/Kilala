-- KILALA: PWD & Senior Citizen Verification System
-- Database: PostgreSQL 13+
-- Schema by Joshua Calibo (Last updated: 10/21/2026)

-- 1. Custom ENUM Types
CREATE TYPE user_role AS ENUM ('LGU_ADMIN', 'CARDHOLDER', 'BUSINESS');
CREATE TYPE privilege_type AS ENUM ('PWD', 'SENIOR_CITIZEN');
CREATE TYPE card_status AS ENUM ('ACTIVE', 'EXPIRED', 'REVOKED', 'SUSPENDED');
CREATE TYPE business_category AS ENUM (
    'PHARMACY',
    'RESTAURANT',
    'GROCERY',
    'TRANSPORT',
    'MEDICAL',
    'ENTERTAINMENT',
    'OTHER'
);

-- 2. Tables

-- 2.1 Local Government Units (Issuing Authorities)
CREATE TABLE lgus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lgu_code VARCHAR(20) UNIQUE NOT NULL,       -- e.g., 'MKT', 'MNL', 'QC'
    municipality_name VARCHAR(150) NOT NULL,    -- e.g., 'Makati City'
    province VARCHAR(150),                      -- NULL for NCR cities
    region VARCHAR(100) NOT NULL,               -- e.g., 'NCR'
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2.2 Users (Central Authentication Table)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2.3 LGU Administrators (Web Portal Users)
CREATE TABLE lgu_admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lgu_id UUID NOT NULL REFERENCES lgus(id) ON DELETE RESTRICT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    department VARCHAR(100) NOT NULL,           -- e.g., 'OSCA' (Senior) or 'PDAO' (PWD)
    position VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2.4 Cardholder Profiles (PWDs and Senior Citizens)
CREATE TABLE cardholder_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL, -- Nullable if unclaimed on mobile
    lgu_id UUID NOT NULL REFERENCES lgus(id) ON DELETE RESTRICT,
    issued_by_admin_id UUID REFERENCES lgu_admins(id) ON DELETE SET NULL,
    lgu_id_number VARCHAR(100) UNIQUE NOT NULL, -- Official physical ID number
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    sex VARCHAR(20) NOT NULL,
    address TEXT NOT NULL,
    contact_number VARCHAR(30),
    emergency_contact_name VARCHAR(150),
    emergency_contact_phone VARCHAR(30),
    privilege_type privilege_type NOT NULL,
    disability_type VARCHAR(150),               -- e.g., 'Orthopedic', 'Visual', 'Psychosocial'
    status card_status NOT NULL DEFAULT 'ACTIVE',
    qr_secret_token VARCHAR(255) UNIQUE NOT NULL,
    photo_url TEXT,
    issued_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,                           -- NULL for lifetime Senior cards; 3-5 yrs for PWD
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Business Rule: PWD records must specify a disability_type; Senior Citizens do not
    CONSTRAINT chk_disability_type CHECK (
        (privilege_type = 'PWD' AND disability_type IS NOT NULL) OR
        (privilege_type = 'SENIOR_CITIZEN')
    )
);

-- 2.5 Business Profiles (Merchants / Commercial Establishments)
CREATE TABLE business_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lgu_id UUID NOT NULL REFERENCES lgus(id) ON DELETE RESTRICT,
    business_name VARCHAR(200) NOT NULL,
    branch_name VARCHAR(200),
    category business_category NOT NULL DEFAULT 'OTHER',
    business_permit_no VARCHAR(100) UNIQUE NOT NULL,
    tin_number VARCHAR(50) NOT NULL,
    address TEXT NOT NULL,
    is_accredited BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2.6 Verification Logs (QR Scan Audit Trail)
CREATE TABLE verification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cardholder_id UUID REFERENCES cardholder_profiles(id) ON DELETE SET NULL,
    business_id UUID NOT NULL REFERENCES business_profiles(id) ON DELETE CASCADE,
    status_at_scan card_status NOT NULL,
    is_valid BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),                -- e.g., 'Card Expired', 'Revoked by LGU'
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Indexes for Fast Query & Scan Performance

-- Instant lookup during iOS QR scan
CREATE INDEX idx_cardholders_qr_token ON cardholder_profiles(qr_secret_token);

-- Fast filtering on the LGU Web Admin Dashboard
CREATE INDEX idx_cardholders_lgu_status ON cardholder_profiles(lgu_id, status, privilege_type);
CREATE INDEX idx_cardholders_last_name ON cardholder_profiles(last_name, first_name);

-- Fast history retrieval for iOS Cardholder & Business history tabs
CREATE INDEX idx_logs_cardholder_time ON verification_logs(cardholder_id, scanned_at DESC);
CREATE INDEX idx_logs_business_time ON verification_logs(business_id, scanned_at DESC);

-- 4. Automatic `updated_at` Timestamp Trigger

CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW; END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_cardholders_updated_at
    BEFORE UPDATE ON cardholder_profiles
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER trg_businesses_updated_at
    BEFORE UPDATE ON business_profiles
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

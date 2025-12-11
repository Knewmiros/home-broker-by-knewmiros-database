-- schema.sql
-- Drops everything (for clean dev setup)
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- Enable pgcrypto for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================= ORGANISATIONS =================

CREATE TABLE organisations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    brands TEXT[],
    type VARCHAR(100),
    address TEXT,
    suburb VARCHAR(100),
    postcode VARCHAR(20),
    state VARCHAR(100), 
    country VARCHAR(100),
    phone VARCHAR(100),
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================= USERS =================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    organisation_name VARCHAR(255) REFERENCES organisations(name),
    organisation_type VARCHAR(100),
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'broker',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_organisations_name ON organisations(name);

-- ================= JOB DATA   =================

CREATE TABLE job_data (
    id SERIAL PRIMARY KEY,
    organisation_name VARCHAR(255) REFERENCES organisations(name),
    user_id UUID REFERENCES users(id),
    locked BOOLEAN DEFAULT FALSE,
    builder TEXT[],
    sketch_required BOOLEAN,
    costing_required BOOLEAN,
    deadline DATE,
    buyer1_name VARCHAR(255) NOT NULL,
    buyer1_address VARCHAR(255) NOT NULL,
    buyer1_email VARCHAR(255) NOT NULL,
    buyer1_phone VARCHAR(100),
    buyer1_notes TEXT,
    buyer2_name VARCHAR(255) NOT NULL,
    buyer2_address VARCHAR(255) NOT NULL,
    buyer2_email VARCHAR(255) NOT NULL,
    buyer2_phone VARCHAR(100),
    buyer2_notes TEXT,
    investor_client BOOLEAN,
    min_budget NUMERIC,
    max_budget NUMERIC,
    address TEXT,
    suburb VARCHAR(100),
    postcode VARCHAR(20),
    shire VARCHAR(100),
    estate_name VARCHAR(255),
    size VARCHAR(100),
    bal VARCHAR(50),
    planning_required BOOLEAN,
    zoning VARCHAR(100),
    coastal VARCHAR(50),
    noise_required BOOLEAN,
    accessible_site VARCHAR(100),
    titled BOOLEAN,
    land_type VARCHAR(100),
    services_water BOOLEAN,
    services_sewer BOOLEAN,
    services_power BOOLEAN,
    services_gas BOOLEAN,
    area_loading_required BOOLEAN,
    fixed_cost_siteworks BOOLEAN,
    base_model VARCHAR(255),
    specification TEXT,
    consultant_name VARCHAR(255),
    additional_commission NUMERIC,
    uploaded_files TEXT[],
    uploaded_quote TEXT[], 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================= COMMISSION =================

CREATE TABLE commissions (
    id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES job_data(id) ON DELETE CASCADE,
    type VARCHAR(255),
    receiver VARCHAR(255),
    commission NUMERIC,
    margin NUMERIC ,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

-- ================= COSTING REQUEST =================

CREATE TABLE costing_request (
    id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES job_data(id) ON DELETE CASCADE,
    request_no INTEGER,
    date DATE,
    locked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================= REQUEST CONTENT =================

CREATE TABLE request_content (
    id SERIAL PRIMARY KEY,
    costing_request_id INTEGER REFERENCES costing_request(id) ON DELETE CASCADE,
    sequence_number INTEGER NOT NULL,
    description TEXT ,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -- ================= BUYER DETAILS =================

-- CREATE TABLE buyer_details (
--     id SERIAL PRIMARY KEY,
--     -- job_id INTEGER REFERENCES job_data(id) ON DELETE CASCADE,
--     buyer_name VARCHAR(255) NOT NULL,
--     buyer_email VARCHAR(255) NOT NULL,
--     buyer_phone VARCHAR(100),
--     buyer_address TEXT,
--     buyer_notes TEXT,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- ================= UPLOADED FILES TABLE =================

CREATE TABLE uploaded_files (
  id SERIAL PRIMARY KEY,
  job_id INTEGER REFERENCES job_data(id) ON DELETE CASCADE,
  list_name VARCHAR(255) NOT NULL,
  filename VARCHAR(255) NOT NULL,
  original_name VARCHAR(255) NOT NULL,
  path VARCHAR(500) NOT NULL,
  size INT NOT NULL,
  mimetype VARCHAR(100) NOT NULL,   
  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ================= BUILDER SUBMISSION =================

CREATE TABLE builder_submission (
    id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES job_data(id) ON DELETE CASCADE,
    builder_name VARCHAR(255) NOT NULL,
    brand VARCHAR(255) NOT NULL,    
    type VARCHAR(255) NOT NULL,
    submission_date DATE,
    price NUMERIC,
    notes TEXT,
    quote_accepted BOOLEAN DEFAULT FALSE,
    quote_filename VARCHAR(255),
    quote_original_name VARCHAR(255),
    quote_file_path VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create session table for storing express-session data
CREATE TABLE session (
  sid varchar NOT NULL COLLATE "default",
  sess json NOT NULL,
  expire timestamp(6) NOT NULL,
  CONSTRAINT "session_pkey" PRIMARY KEY ("sid")
);

-- Create index on expire column for efficient cleanup of expired sessions
CREATE INDEX IF NOT EXISTS "IDX_session_expire" ON "session" ("expire");

-- Grant permissions to broker_app user
GRANT ALL PRIVILEGES ON TABLE "session" TO broker_app;
GRANT ALL PRIVILEGES ON TABLE "session" TO postgres;
-- Note: Application user (broker_app) is created by 02-create-app-user.sh
-- This allows the password to come from environment variable BROKER_APP_PASSWORD



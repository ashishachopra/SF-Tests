-- ============================================================================
-- 01_setup_database_and_load_data.sql
-- Creates the database, schema, tables, and loads demo data from CSV files
-- 
-- PREREQUISITE: Git integration must be set up first (see developer guide)
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- CREATE DATABASE AND SCHEMA
-- ============================================================================

CREATE DATABASE IF NOT EXISTS CUSTOMER_INTELLIGENCE_DB;
USE DATABASE CUSTOMER_INTELLIGENCE_DB;

CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

-- ============================================================================
-- CUSTOMERS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id VARCHAR(50) PRIMARY KEY,
    signup_date DATE NOT NULL,
    plan_type VARCHAR(20) NOT NULL,
    company_size VARCHAR(20) NOT NULL,
    industry VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    monthly_revenue DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- USAGE_EVENTS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE USAGE_EVENTS (
    event_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    event_date DATE NOT NULL,
    feature_used VARCHAR(50) NOT NULL,
    session_duration_minutes INTEGER NOT NULL,
    actions_count INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- SUPPORT_TICKETS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE SUPPORT_TICKETS (
    ticket_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    created_date DATE NOT NULL,
    category VARCHAR(30) NOT NULL,
    priority VARCHAR(10) NOT NULL,
    status VARCHAR(20) NOT NULL,
    resolution_time_hours INTEGER,
    satisfaction_score INTEGER,
    ticket_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- CHURN_EVENTS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE CHURN_EVENTS (
    churn_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    churn_date DATE NOT NULL,
    churn_reason VARCHAR(50) NOT NULL,
    days_since_signup INTEGER NOT NULL,
    final_plan_type VARCHAR(20),
    final_monthly_revenue DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- LOAD DEMO DATA FROM CSV FILES
-- ============================================================================

-- Create file format
CREATE OR REPLACE FILE FORMAT CUSTOMER_INTELLIGENCE_DB.PUBLIC.csv_format
    TYPE = CSV 
    SKIP_HEADER = 1 
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null') 
    EMPTY_FIELD_AS_NULL = TRUE;

-- Clear existing data (in case of re-run)
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS;
TRUNCATE TABLE IF EXISTS CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS;

-- Load CUSTOMERS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS (customer_id, signup_date, plan_type, company_size, industry, status, monthly_revenue)
SELECT $1,$2,$3,$4,$5,$6,$7 
FROM @customer_intelligence_demo/branches/main/demo_customers.csv (FILE_FORMAT=>csv_format);

-- Load USAGE_EVENTS  
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.USAGE_EVENTS (event_id, customer_id, event_date, feature_used, session_duration_minutes, actions_count)
SELECT $1,$2,$3,$4,$5,$6 
FROM @customer_intelligence_demo/branches/main/demo_usage_events.csv (FILE_FORMAT=>csv_format);

-- Load SUPPORT_TICKETS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS (ticket_id, customer_id, created_date, category, priority, status, resolution_time_hours, satisfaction_score, ticket_text)
SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9 
FROM @customer_intelligence_demo/branches/main/demo_support_tickets.csv (FILE_FORMAT=>csv_format);

-- Load CHURN_EVENTS
INSERT INTO CUSTOMER_INTELLIGENCE_DB.PUBLIC.CHURN_EVENTS (churn_id, customer_id, churn_date, churn_reason, days_since_signup, final_plan_type, final_monthly_revenue)
SELECT $1,$2,$3,$4,$5,$6,$7 
FROM @customer_intelligence_demo/branches/main/demo_churn_events.csv (FILE_FORMAT=>csv_format);

-- ============================================================================
-- VERIFY SETUP
-- ============================================================================
SHOW TABLES IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;

SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM CUSTOMERS
UNION ALL SELECT 'USAGE_EVENTS', COUNT(*) FROM USAGE_EVENTS
UNION ALL SELECT 'SUPPORT_TICKETS', COUNT(*) FROM SUPPORT_TICKETS
UNION ALL SELECT 'CHURN_EVENTS', COUNT(*) FROM CHURN_EVENTS;


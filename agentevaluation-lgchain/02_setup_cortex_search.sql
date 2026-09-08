-- ============================================================================
-- 02_setup_cortex_search.sql
-- Creates Cortex Search services for the agents
-- ============================================================================

USE DATABASE CUSTOMER_INTELLIGENCE_DB;
USE SCHEMA PUBLIC;

-- ============================================================================
-- SUPPORT TICKETS SEARCH SERVICE
-- Used by CONTENT_AGENT for customer feedback and support analysis
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS_SEARCH
ON ticket_text
ATTRIBUTES customer_id, ticket_id, category, priority, status, created_date
WAREHOUSE = COMPUTE_WH
TARGET_LAG = '1 hour'
AS (
    SELECT 
        ticket_id,
        customer_id,
        category,
        priority,
        status,
        created_date,
        ticket_text
    FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS
);

-- ============================================================================
-- CUSTOMERS SEARCH SERVICE (Optional)
-- Used by RESEARCH_AGENT for customer segment analysis
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS_SEARCH
ON industry
ATTRIBUTES customer_id, plan_type, company_size, status, monthly_revenue
WAREHOUSE = COMPUTE_WH
TARGET_LAG = '1 hour'
AS (
    SELECT 
        customer_id,
        plan_type,
        company_size,
        industry,
        status,
        monthly_revenue
    FROM CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMERS
);

-- ============================================================================
-- VERIFY
-- ============================================================================
SHOW CORTEX SEARCH SERVICES IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;


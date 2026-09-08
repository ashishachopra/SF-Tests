-- ============================================================================
-- View Investigation and Fix Script
-- Database: A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY
-- Purpose: Investigate and fix views referencing non-existent edge types
-- ============================================================================

USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;
USE WAREHOUSE GBU_A01A0E_FINCRIME_DE_POC_WH_4XL;

-- ============================================================================
-- SECTION 1: INVESTIGATE PROBLEMATIC VIEWS
-- ============================================================================

-- Check current view definitions
SELECT 'Investigating problematic views...' AS status;

-- Check V_CUST_DEVICE_OWNED
SELECT 'View: V_CUST_DEVICE_OWNED' AS view_name;
SHOW VIEWS LIKE 'V_CUST_DEVICE_OWNED';

-- Check V_CUST_PRODUCT_OWNED  
SELECT 'View: V_CUST_PRODUCT_OWNED' AS view_name;
SHOW VIEWS LIKE 'V_CUST_PRODUCT_OWNED';

-- Check V_CUST_TXN_DONE
SELECT 'View: V_CUST_TXN_DONE' AS view_name;
SHOW VIEWS LIKE 'V_CUST_TXN_DONE';

-- Check V_PRODUCT_TXN_DONE
SELECT 'View: V_PRODUCT_TXN_DONE' AS view_name;
SHOW VIEWS LIKE 'V_PRODUCT_TXN_DONE';

-- ============================================================================
-- SECTION 2: IDENTIFY CORRECT EDGE TYPE MAPPINGS
-- ============================================================================

SELECT 'Analyzing actual edge types in KG_EDGE...' AS status;

-- Customer-Device relationships (for V_CUST_DEVICE_OWNED)
SELECT 
    'Customer-Device edges' AS relationship,
    EDGE_TYPE,
    COUNT(*) AS count
FROM KG_EDGE
WHERE EDGE_TYPE IN ('USES_DEVICE', 'USED_DEVICE', 'USED_BY')
GROUP BY EDGE_TYPE
ORDER BY count DESC;

-- Customer-Account relationships (for V_CUST_PRODUCT_OWNED - assuming Product = Account)
SELECT 
    'Customer-Account edges' AS relationship,
    EDGE_TYPE,
    COUNT(*) AS count
FROM KG_EDGE
WHERE EDGE_TYPE IN ('OWNS', 'CO_OWNER')
GROUP BY EDGE_TYPE
ORDER BY count DESC;

-- Customer-Transaction relationships (for V_CUST_TXN_DONE)
SELECT 
    'Customer-Transaction edges (via Account)' AS relationship,
    EDGE_TYPE,
    COUNT(*) AS count
FROM KG_EDGE
WHERE EDGE_TYPE IN ('FROM_ACCOUNT', 'TO_ACCOUNT', 'TRANSACTED')
GROUP BY EDGE_TYPE
ORDER BY count DESC;

-- Account-Transaction relationships (for V_PRODUCT_TXN_DONE - assuming Product = Account)
SELECT 
    'Account-Transaction edges' AS relationship,
    EDGE_TYPE,
    COUNT(*) AS count
FROM KG_EDGE
WHERE EDGE_TYPE IN ('FROM_ACCOUNT', 'TO_ACCOUNT', 'TRANSACTED')
GROUP BY EDGE_TYPE
ORDER BY count DESC;

-- ============================================================================
-- SECTION 3: FIX OPTION A - Update Views to Use Existing Edge Types
-- ============================================================================
-- This option assumes the views should reference existing edge types

-- Fix V_CUST_DEVICE_OWNED - Use USES_DEVICE instead of CUSTOMER_DEVICE
CREATE OR REPLACE VIEW V_CUST_DEVICE_OWNED AS
SELECT 
    SRC_ID AS customer_id,
    DST_ID AS device_id,
    EDGE_TYPE,
    EFFECTIVE_START,
    EFFECTIVE_END
FROM KG_EDGE
WHERE EDGE_TYPE = 'USES_DEVICE';

-- Fix V_CUST_PRODUCT_OWNED - Use OWNS instead of CUST_OWNS_PRODUCT
CREATE OR REPLACE VIEW V_CUST_PRODUCT_OWNED AS
SELECT 
    SRC_ID AS customer_id,
    DST_ID AS account_id,
    EDGE_TYPE,
    EFFECTIVE_START,
    EFFECTIVE_END
FROM KG_EDGE
WHERE EDGE_TYPE = 'OWNS';

-- Fix V_CUST_TXN_DONE - Use FROM_ACCOUNT to link Customer->Account->Transaction
CREATE OR REPLACE VIEW V_CUST_TXN_DONE AS
SELECT DISTINCT
    co.SRC_ID AS customer_id,
    ta.SRC_ID AS transaction_id,
    ta.EDGE_TYPE AS transaction_edge_type,
    ta.EFFECTIVE_START,
    ta.EFFECTIVE_END
FROM KG_EDGE co
INNER JOIN KG_EDGE ta 
    ON co.DST_ID = ta.DST_ID 
    AND co.EDGE_TYPE = 'OWNS'
    AND ta.EDGE_TYPE = 'FROM_ACCOUNT';

-- Fix V_PRODUCT_TXN_DONE - Use FROM_ACCOUNT and TO_ACCOUNT
CREATE OR REPLACE VIEW V_PRODUCT_TXN_DONE AS
SELECT 
    DST_ID AS account_id,
    SRC_ID AS transaction_id,
    EDGE_TYPE,
    EFFECTIVE_START,
    EFFECTIVE_END
FROM KG_EDGE
WHERE EDGE_TYPE IN ('FROM_ACCOUNT', 'TO_ACCOUNT', 'TRANSACTED');

SELECT 'Views updated to use existing edge types' AS status;

-- ============================================================================
-- SECTION 4: FIX OPTION B - Create Missing Edge Types in KG_EDGE
-- ============================================================================
-- Uncomment this section if you want to ADD the missing edge types to KG_EDGE
-- rather than updating the views

/*
-- Create CUSTOMER_DEVICE edges based on USES_DEVICE
INSERT INTO KG_EDGE (
    EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, 
    EFFECTIVE_START, EFFECTIVE_END, 
    PROPS
)
SELECT 
    'CD_' || EDGE_ID AS EDGE_ID,
    SRC_ID,
    DST_ID,
    'CUSTOMER_DEVICE' AS EDGE_TYPE,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE = 'USES_DEVICE';

-- Create CUST_OWNS_PRODUCT edges based on OWNS
INSERT INTO KG_EDGE (
    EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, 
    EFFECTIVE_START, EFFECTIVE_END, 
    PROPS
)
SELECT 
    'COP_' || EDGE_ID AS EDGE_ID,
    SRC_ID,
    DST_ID,
    'CUST_OWNS_PRODUCT' AS EDGE_TYPE,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE = 'OWNS';

-- Create CUSTOMER_TRANSACTIONS edges
INSERT INTO KG_EDGE (
    EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, 
    EFFECTIVE_START, EFFECTIVE_END, 
    PROPS
)
SELECT DISTINCT
    'CT_' || co.EDGE_ID || '_' || ta.EDGE_ID AS EDGE_ID,
    co.SRC_ID AS SRC_ID,  -- customer_id
    ta.SRC_ID AS DST_ID,  -- transaction_id
    'CUSTOMER_TRANSACTIONS' AS EDGE_TYPE,
    GREATEST(co.EFFECTIVE_START, ta.EFFECTIVE_START) AS EFFECTIVE_START,
    LEAST(co.EFFECTIVE_END, ta.EFFECTIVE_END) AS EFFECTIVE_END,
    NULL AS PROPS
FROM KG_EDGE co
INNER JOIN KG_EDGE ta 
    ON co.DST_ID = ta.DST_ID 
WHERE co.EDGE_TYPE = 'OWNS'
  AND ta.EDGE_TYPE = 'FROM_ACCOUNT';

-- Create PRODUCT_TRANSACTIONS edges (same as FROM_ACCOUNT + TO_ACCOUNT)
INSERT INTO KG_EDGE (
    EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, 
    EFFECTIVE_START, EFFECTIVE_END, 
    PROPS
)
SELECT 
    'PT_' || EDGE_ID AS EDGE_ID,
    DST_ID AS SRC_ID,  -- account_id becomes source
    SRC_ID AS DST_ID,  -- transaction_id becomes destination
    'PRODUCT_TRANSACTIONS' AS EDGE_TYPE,
    EFFECTIVE_START,
    EFFECTIVE_END,
    PROPS
FROM KG_EDGE
WHERE EDGE_TYPE IN ('FROM_ACCOUNT', 'TO_ACCOUNT');

-- Add mappings to ONT_LINK_SOURCE for new edge types
INSERT INTO ONT_LINK_SOURCE (ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
VALUES
    ('GRAPH_ONTOLOGY', 'CUSTOMER_DEVICE', 'KG_EDGE', 'EDGE_TYPE = ''CUSTOMER_DEVICE''', 
     PARSE_JSON('{"SRC_ID":"customer_id","DST_ID":"device_id","EFFECTIVE_START":"effective_start","EFFECTIVE_END":"effective_end"}')),
    ('GRAPH_ONTOLOGY', 'CUST_OWNS_PRODUCT', 'KG_EDGE', 'EDGE_TYPE = ''CUST_OWNS_PRODUCT''', 
     PARSE_JSON('{"SRC_ID":"customer_id","DST_ID":"account_id","EFFECTIVE_START":"effective_start","EFFECTIVE_END":"effective_end"}')),
    ('GRAPH_ONTOLOGY', 'CUSTOMER_TRANSACTIONS', 'KG_EDGE', 'EDGE_TYPE = ''CUSTOMER_TRANSACTIONS''', 
     PARSE_JSON('{"SRC_ID":"customer_id","DST_ID":"transaction_id","EFFECTIVE_START":"effective_start","EFFECTIVE_END":"effective_end"}')),
    ('GRAPH_ONTOLOGY', 'PRODUCT_TRANSACTIONS', 'KG_EDGE', 'EDGE_TYPE = ''PRODUCT_TRANSACTIONS''', 
     PARSE_JSON('{"SRC_ID":"account_id","DST_ID":"transaction_id","EFFECTIVE_START":"effective_start","EFFECTIVE_END":"effective_end"}'));

SELECT 'New edge types created and mapped in ONT_LINK_SOURCE' AS status;
*/

-- ============================================================================
-- SECTION 5: VALIDATION - Test Views
-- ============================================================================

SELECT 'Testing updated views...' AS status;

-- Test V_CUST_DEVICE_OWNED
SELECT 'V_CUST_DEVICE_OWNED' AS view_name, COUNT(*) AS row_count 
FROM V_CUST_DEVICE_OWNED;

-- Test V_CUST_PRODUCT_OWNED
SELECT 'V_CUST_PRODUCT_OWNED' AS view_name, COUNT(*) AS row_count 
FROM V_CUST_PRODUCT_OWNED;

-- Test V_CUST_TXN_DONE
SELECT 'V_CUST_TXN_DONE' AS view_name, COUNT(*) AS row_count 
FROM V_CUST_TXN_DONE;

-- Test V_PRODUCT_TXN_DONE
SELECT 'V_PRODUCT_TXN_DONE' AS view_name, COUNT(*) AS row_count 
FROM V_PRODUCT_TXN_DONE;

-- Show sample data from each view
SELECT 'Sample from V_CUST_DEVICE_OWNED:' AS view_name;
SELECT * FROM V_CUST_DEVICE_OWNED LIMIT 5;

SELECT 'Sample from V_CUST_PRODUCT_OWNED:' AS view_name;
SELECT * FROM V_CUST_PRODUCT_OWNED LIMIT 5;

SELECT 'Sample from V_CUST_TXN_DONE:' AS view_name;
SELECT * FROM V_CUST_TXN_DONE LIMIT 5;

SELECT 'Sample from V_PRODUCT_TXN_DONE:' AS view_name;
SELECT * FROM V_PRODUCT_TXN_DONE LIMIT 5;

-- ============================================================================
-- SECTION 6: FINAL VALIDATION
-- ============================================================================

SELECT '============================================================' AS status;
SELECT 'VIEW FIX VALIDATION' AS status;
SELECT '============================================================' AS status;

-- Check if all views now return data
WITH view_counts AS (
    SELECT 'V_CUST_DEVICE_OWNED' AS view_name, 
           (SELECT COUNT(*) FROM V_CUST_DEVICE_OWNED) AS row_count
    UNION ALL
    SELECT 'V_CUST_PRODUCT_OWNED', 
           (SELECT COUNT(*) FROM V_CUST_PRODUCT_OWNED)
    UNION ALL
    SELECT 'V_CUST_TXN_DONE', 
           (SELECT COUNT(*) FROM V_CUST_TXN_DONE)
    UNION ALL
    SELECT 'V_PRODUCT_TXN_DONE', 
           (SELECT COUNT(*) FROM V_PRODUCT_TXN_DONE)
)
SELECT 
    view_name,
    row_count,
    CASE 
        WHEN row_count > 0 THEN '✓ Working'
        ELSE '✗ Empty'
    END AS status
FROM view_counts;

SELECT '============================================================' AS status;
SELECT 'VIEW FIX SCRIPT COMPLETED!' AS status;
SELECT '============================================================' AS status;

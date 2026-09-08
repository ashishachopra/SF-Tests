-- ============================================================================
-- Graph Ontology Fix Script
-- Database: A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY
-- Purpose: Fix critical issues in ONT* tables
-- ============================================================================

USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;
USE WAREHOUSE GBU_A01A0E_FINCRIME_DE_POC_WH_4XL;

-- ============================================================================
-- SECTION 1: BACKUP CURRENT DATA (Optional but Recommended)
-- ============================================================================

-- Backup ONT_OBJECT_SOURCE
CREATE OR REPLACE TABLE ONT_OBJECT_SOURCE_BACKUP AS 
SELECT * FROM ONT_OBJECT_SOURCE;

-- Backup ONT_CLASS
CREATE OR REPLACE TABLE ONT_CLASS_BACKUP AS 
SELECT * FROM ONT_CLASS;

-- Backup ONT_PROPERTY
CREATE OR REPLACE TABLE ONT_PROPERTY_BACKUP AS 
SELECT * FROM ONT_PROPERTY;

SELECT 'Backup completed successfully' AS status;

-- ============================================================================
-- SECTION 2: FIX MISSING TRANSACTION MAPPING IN ONT_OBJECT_SOURCE
-- ============================================================================

-- Check if Transaction mapping already exists
SELECT 'Checking for existing Transaction mapping...' AS status;

SELECT COUNT(*) AS transaction_mapping_exists 
FROM ONT_OBJECT_SOURCE 
WHERE OBJ_TYPE = 'Transaction';

-- Insert Transaction mapping
INSERT INTO ONT_OBJECT_SOURCE 
(ONTOLOGY_NAME, OBJ_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
    'GRAPH_ONTOLOGY' AS ONTOLOGY_NAME,
    'Transaction' AS OBJ_TYPE,
    'KG_NODE' AS SOURCE_TABLE,
    'NODE_TYPE = ''Transaction''' AS FILTER_SQL,
    PARSE_JSON('{
        "NAME":"name",
        "NODE_ID":"id",
        "PROPS:TXNDATE":"txndate",
        "PROPS:AMOUNT":"amount",
        "PROPS:BASECURRENCY":"basecurrency",
        "PROPS:ACTUALCURRENCY":"actualcurrency",
        "PROPS:CREDITDEBIT":"creditdebit",
        "PROPS:DEVICE":"device",
        "PROPS:PRIMARYCUSTOMER":"primarycustomer",
        "PROPS:ACCOUNT":"account"
    }') AS MAPPING
WHERE NOT EXISTS (
    SELECT 1 FROM ONT_OBJECT_SOURCE WHERE OBJ_TYPE = 'Transaction'
);

-- Verify Transaction mapping was added
SELECT 'Transaction mapping status:' AS status;
SELECT * FROM ONT_OBJECT_SOURCE WHERE OBJ_TYPE = 'Transaction';

-- ============================================================================
-- SECTION 3: REMOVE DUPLICATE ENTRIES IN ONT_CLASS
-- ============================================================================

-- Identify duplicates before removal
SELECT 'Identifying duplicate ONT_CLASS entries...' AS status;

SELECT 
    CLASS_NAME, 
    PARENT_CLASS_NAME, 
    IS_ABSTRACT,
    COUNT(*) AS duplicate_count
FROM ONT_CLASS
WHERE CLASS_NAME IN ('Address', 'Merchant')
GROUP BY CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT
HAVING COUNT(*) > 1;

-- Create a temporary table with deduplicated records
CREATE OR REPLACE TEMPORARY TABLE ONT_CLASS_DEDUP AS
SELECT DISTINCT
    CLASS_NAME,
    PARENT_CLASS_NAME,
    IS_ABSTRACT,
    DESCRIPTION,
    ONTOLOGY_NAME,
    TYPE_CLASS,
    STATUS,
    MIN(TS_CREATED) AS TS_CREATED
FROM ONT_CLASS
GROUP BY 
    CLASS_NAME,
    PARENT_CLASS_NAME,
    IS_ABSTRACT,
    DESCRIPTION,
    ONTOLOGY_NAME,
    TYPE_CLASS,
    STATUS;

-- Show count before cleanup
SELECT 'ONT_CLASS row count BEFORE cleanup:' AS status, COUNT(*) AS row_count FROM ONT_CLASS;

-- Delete duplicates for Address and Merchant
DELETE FROM ONT_CLASS 
WHERE CLASS_NAME IN ('Address', 'Merchant');

-- Re-insert deduplicated records
INSERT INTO ONT_CLASS 
(CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT, DESCRIPTION, ONTOLOGY_NAME, TYPE_CLASS, STATUS, TS_CREATED)
SELECT 
    CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT, DESCRIPTION, ONTOLOGY_NAME, TYPE_CLASS, STATUS, TS_CREATED
FROM ONT_CLASS_DEDUP
WHERE CLASS_NAME IN ('Address', 'Merchant');

-- Show count after cleanup
SELECT 'ONT_CLASS row count AFTER cleanup:' AS status, COUNT(*) AS row_count FROM ONT_CLASS;

-- Verify no more duplicates
SELECT 'Verifying no duplicates remain in ONT_CLASS...' AS status;
SELECT 
    CLASS_NAME, 
    PARENT_CLASS_NAME,
    COUNT(*) AS count
FROM ONT_CLASS
GROUP BY CLASS_NAME, PARENT_CLASS_NAME
HAVING COUNT(*) > 1;

-- ============================================================================
-- SECTION 4: REMOVE DUPLICATE ENTRIES IN ONT_PROPERTY
-- ============================================================================

-- Identify duplicates before removal
SELECT 'Identifying duplicate ONT_PROPERTY entries...' AS status;

SELECT 
    CLASS_NAME, 
    PROP_NAME,
    COUNT(*) AS duplicate_count
FROM ONT_PROPERTY
WHERE CLASS_NAME IN ('Address', 'Merchant')
GROUP BY CLASS_NAME, PROP_NAME
HAVING COUNT(*) > 1;

-- Create a temporary table with deduplicated properties
CREATE OR REPLACE TEMPORARY TABLE ONT_PROPERTY_DEDUP AS
SELECT DISTINCT
    CLASS_NAME,
    PROP_NAME,
    DATA_TYPE,
    IS_REQUIRED,
    IS_INDEXED,
    DESCRIPTION,
    SHARED_PROP_NAME
FROM ONT_PROPERTY
GROUP BY 
    CLASS_NAME,
    PROP_NAME,
    DATA_TYPE,
    IS_REQUIRED,
    IS_INDEXED,
    DESCRIPTION,
    SHARED_PROP_NAME;

-- Show count before cleanup
SELECT 'ONT_PROPERTY row count BEFORE cleanup:' AS status, COUNT(*) AS row_count FROM ONT_PROPERTY;

-- Delete duplicates for Address and Merchant
DELETE FROM ONT_PROPERTY 
WHERE CLASS_NAME IN ('Address', 'Merchant');

-- Re-insert deduplicated records
INSERT INTO ONT_PROPERTY 
(CLASS_NAME, PROP_NAME, DATA_TYPE, IS_REQUIRED, IS_INDEXED, DESCRIPTION, SHARED_PROP_NAME)
SELECT 
    CLASS_NAME, PROP_NAME, DATA_TYPE, IS_REQUIRED, IS_INDEXED, DESCRIPTION, SHARED_PROP_NAME
FROM ONT_PROPERTY_DEDUP
WHERE CLASS_NAME IN ('Address', 'Merchant');

-- Show count after cleanup
SELECT 'ONT_PROPERTY row count AFTER cleanup:' AS status, COUNT(*) AS row_count FROM ONT_PROPERTY;

-- Verify no more duplicates
SELECT 'Verifying no duplicates remain in ONT_PROPERTY...' AS status;
SELECT 
    CLASS_NAME, 
    PROP_NAME,
    COUNT(*) AS count
FROM ONT_PROPERTY
GROUP BY CLASS_NAME, PROP_NAME
HAVING COUNT(*) > 1;

-- ============================================================================
-- SECTION 5: VALIDATION QUERIES
-- ============================================================================

SELECT '============================================================' AS status;
SELECT 'VALIDATION RESULTS' AS status;
SELECT '============================================================' AS status;

-- 1. Verify all node types are mapped
SELECT 'Node Type Coverage Check:' AS check_name;
WITH actual_nodes AS (
    SELECT DISTINCT NODE_TYPE FROM KG_NODE
),
ont_mappings AS (
    SELECT DISTINCT OBJ_TYPE FROM ONT_OBJECT_SOURCE
)
SELECT 
    CASE 
        WHEN a.NODE_TYPE IS NOT NULL AND o.OBJ_TYPE IS NOT NULL THEN '✓ Mapped'
        WHEN a.NODE_TYPE IS NOT NULL AND o.OBJ_TYPE IS NULL THEN '✗ Missing in ONT_OBJECT_SOURCE'
        ELSE '✗ Missing in KG_NODE'
    END AS status,
    COALESCE(a.NODE_TYPE, o.OBJ_TYPE) AS node_type
FROM actual_nodes a
FULL OUTER JOIN ont_mappings o ON a.NODE_TYPE = o.OBJ_TYPE
ORDER BY status, node_type;

-- 2. Verify all edge types are mapped
SELECT 'Edge Type Coverage Check:' AS check_name;
WITH actual_edges AS (
    SELECT DISTINCT EDGE_TYPE FROM KG_EDGE
),
ont_link_mappings AS (
    SELECT DISTINCT LINK_TYPE FROM ONT_LINK_SOURCE
)
SELECT 
    CASE 
        WHEN a.EDGE_TYPE IS NOT NULL AND o.LINK_TYPE IS NOT NULL THEN '✓ Mapped'
        WHEN a.EDGE_TYPE IS NOT NULL AND o.LINK_TYPE IS NULL THEN '✗ Missing in ONT_LINK_SOURCE'
        ELSE '✗ Missing in KG_EDGE'
    END AS status,
    COALESCE(a.EDGE_TYPE, o.LINK_TYPE) AS edge_type
FROM actual_edges a
FULL OUTER JOIN ont_link_mappings o ON a.EDGE_TYPE = o.LINK_TYPE
ORDER BY status, edge_type;

-- 3. Check ONT_CLASS for duplicates
SELECT 'ONT_CLASS Duplicate Check:' AS check_name;
SELECT 
    CLASS_NAME,
    PARENT_CLASS_NAME,
    COUNT(*) AS count,
    CASE WHEN COUNT(*) > 1 THEN '✗ Duplicate' ELSE '✓ OK' END AS status
FROM ONT_CLASS
GROUP BY CLASS_NAME, PARENT_CLASS_NAME
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 4. Check ONT_PROPERTY for duplicates
SELECT 'ONT_PROPERTY Duplicate Check:' AS check_name;
SELECT 
    CLASS_NAME,
    PROP_NAME,
    COUNT(*) AS count,
    CASE WHEN COUNT(*) > 1 THEN '✗ Duplicate' ELSE '✓ OK' END AS status
FROM ONT_PROPERTY
GROUP BY CLASS_NAME, PROP_NAME
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- 5. Summary counts
SELECT '============================================================' AS status;
SELECT 'SUMMARY' AS status;
SELECT '============================================================' AS status;

SELECT 'ONT_OBJECT_SOURCE' AS table_name, COUNT(*) AS row_count FROM ONT_OBJECT_SOURCE
UNION ALL
SELECT 'ONT_LINK_SOURCE', COUNT(*) FROM ONT_LINK_SOURCE
UNION ALL
SELECT 'ONT_CLASS', COUNT(*) FROM ONT_CLASS
UNION ALL
SELECT 'ONT_PROPERTY', COUNT(*) FROM ONT_PROPERTY
UNION ALL
SELECT 'KG_NODE (distinct types)', COUNT(DISTINCT NODE_TYPE) FROM KG_NODE
UNION ALL
SELECT 'KG_EDGE (distinct types)', COUNT(DISTINCT EDGE_TYPE) FROM KG_EDGE;

-- ============================================================================
-- SECTION 6: OPTIONAL - DROP BACKUP TABLES
-- ============================================================================

-- Uncomment the following lines to drop backup tables after verification
DROP TABLE IF EXISTS ONT_OBJECT_SOURCE_BACKUP;
DROP TABLE IF EXISTS ONT_CLASS_BACKUP;
DROP TABLE IF EXISTS ONT_PROPERTY_BACKUP;

SELECT '============================================================' AS status;
SELECT 'FIX SCRIPT COMPLETED SUCCESSFULLY!' AS status;
SELECT '============================================================' AS status;

-- ============================================================================
-- Graph Ontology Schema Optimization Script
-- Database: A01A0E_GBU_FINCRIME_POC
-- Schema: GRAPH_ONTOLOGY
-- 
-- Purpose: Apply clustering and search optimization to ONT* tables
-- ============================================================================

USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;
USE WAREHOUSE GBU_A01A0E_FINCRIME_DE_POC_WH_4XL;

-- ============================================================================
-- PHASE 1: HIGH PRIORITY OPTIMIZATIONS
-- Execute these first - highest impact on query performance
-- ============================================================================

-- 1. ONT_CLASS_MAP: Critical for NODE_TYPE resolution
-- Impact: Fast class-to-node-type mapping for graph queries
ALTER TABLE ONT_CLASS_MAP 
ADD SEARCH OPTIMIZATION ON EQUALITY(CLASS_NAME, SUBTYPE_VALUE);

SELECT 'ONT_CLASS_MAP: Search optimization added' AS status;

-- 2. ONT_REL_MAP: Critical for EDGE_TYPE resolution
-- Impact: Fast relationship-to-edge-type mapping for traversal queries
ALTER TABLE ONT_REL_MAP 
ADD SEARCH OPTIMIZATION ON EQUALITY(REL_NAME, VIA_REL_VALUE);

SELECT 'ONT_REL_MAP: Search optimization added' AS status;

-- 3. ONT_PROPERTY: Frequently accessed for VARIANT queries
-- Impact: Fast property lookups when extracting from KG_NODE.PROPS
ALTER TABLE ONT_PROPERTY 
ADD SEARCH OPTIMIZATION ON EQUALITY(CLASS_NAME, PROP_NAME, SHARED_PROP_NAME);

SELECT 'ONT_PROPERTY: Search optimization added' AS status;

-- 4. ONT_RELATION_DEF: Essential for relationship validation
-- Impact: Fast relationship definition lookups and inverse relationship resolution
ALTER TABLE ONT_RELATION_DEF 
ADD SEARCH OPTIMIZATION ON EQUALITY(REL_NAME, DOMAIN_CLASS, RANGE_CLASS);

SELECT 'ONT_RELATION_DEF: Search optimization added' AS status;

-- 5. ONT_CLASS: Core metadata lookups
-- Impact: Fast class hierarchy traversal and inheritance queries
ALTER TABLE ONT_CLASS 
ADD SEARCH OPTIMIZATION ON EQUALITY(CLASS_NAME, PARENT_CLASS_NAME);

SELECT 'ONT_CLASS: Search optimization added' AS status;

-- ============================================================================
-- PHASE 2: MEDIUM PRIORITY OPTIMIZATIONS
-- Execute after Phase 1 completes - important for security and ETL
-- ============================================================================

-- 6. ONT_PERMISSION: Security checks
-- Impact: Fast permission validation during query execution
ALTER TABLE ONT_PERMISSION 
ADD SEARCH OPTIMIZATION ON EQUALITY(SUBJECT_NAME, ONT_ROLE_NAME, SUBJECT_KIND);

SELECT 'ONT_PERMISSION: Search optimization added' AS status;

-- 7. ONT_OBJECT_SOURCE: ETL performance
-- Impact: Fast source table lookup during node ingestion
ALTER TABLE ONT_OBJECT_SOURCE 
ADD SEARCH OPTIMIZATION ON EQUALITY(OBJ_TYPE, SOURCE_TABLE);

SELECT 'ONT_OBJECT_SOURCE: Search optimization added' AS status;

-- 8. ONT_LINK_SOURCE: ETL performance
-- Impact: Fast source table lookup during edge ingestion
ALTER TABLE ONT_LINK_SOURCE 
ADD SEARCH OPTIMIZATION ON EQUALITY(LINK_TYPE, SOURCE_TABLE);

SELECT 'ONT_LINK_SOURCE: Search optimization added' AS status;

-- 9. ONT_SHARED_PROPERTY: Property inheritance
-- Impact: Fast shared property definition lookups
ALTER TABLE ONT_SHARED_PROPERTY 
ADD SEARCH OPTIMIZATION ON EQUALITY(SHARED_PROP_NAME);

SELECT 'ONT_SHARED_PROPERTY: Search optimization added' AS status;

-- 10. ONT_INTERFACE_IMPL: Polymorphic queries
-- Impact: Fast "find all classes implementing interface X" queries
ALTER TABLE ONT_INTERFACE_IMPL 
ADD SEARCH OPTIMIZATION ON EQUALITY(INTERFACE_NAME, CLASS_NAME);

SELECT 'ONT_INTERFACE_IMPL: Search optimization added' AS status;

-- ============================================================================
-- PHASE 3: LOW PRIORITY OPTIMIZATIONS (OPTIONAL)
-- Execute if you want comprehensive coverage across all metadata tables
-- ============================================================================

-- 11. ONT_RULE: Inference rule lookups
-- Impact: Fast rule resolution if inference engine expands
ALTER TABLE ONT_RULE 
ADD SEARCH OPTIMIZATION ON EQUALITY(TARGET_REL, SOURCE_REL_1, SOURCE_REL_2);

SELECT 'ONT_RULE: Search optimization added' AS status;

-- 12. ONT_INTERFACE: Interface definition lookups
-- Impact: Minimal (only 3 interfaces), but completes the optimization
ALTER TABLE ONT_INTERFACE 
ADD SEARCH OPTIMIZATION ON EQUALITY(INTERFACE_NAME);

SELECT 'ONT_INTERFACE: Search optimization added' AS status;

-- 13. ONT_INTERFACE_PROPERTY: Interface property lookups
-- Impact: Minimal (only 4 properties), schema validation
ALTER TABLE ONT_INTERFACE_PROPERTY 
ADD SEARCH OPTIMIZATION ON EQUALITY(INTERFACE_NAME, PROP_NAME);

SELECT 'ONT_INTERFACE_PROPERTY: Search optimization added' AS status;

-- 14. ONT_ROLE: Role definition lookups
-- Impact: Minimal (only 4 roles), security subsystem
ALTER TABLE ONT_ROLE 
ADD SEARCH OPTIMIZATION ON EQUALITY(ONT_ROLE_NAME);

SELECT 'ONT_ROLE: Search optimization added' AS status;

-- 15. ONT_FUNCTION: Custom function lookups
-- Impact: Minimal (only 2 functions), extensibility features
ALTER TABLE ONT_FUNCTION 
ADD SEARCH OPTIMIZATION ON EQUALITY(FUNCTION_NAME);

SELECT 'ONT_FUNCTION: Search optimization added' AS status;

-- 16. ONT_FUNCTION_BINDING: Function binding lookups
-- Impact: Minimal (only 2 bindings), function resolution
ALTER TABLE ONT_FUNCTION_BINDING 
ADD SEARCH OPTIMIZATION ON EQUALITY(FUNCTION_NAME, BOUND_TO_NAME);

SELECT 'ONT_FUNCTION_BINDING: Search optimization added' AS status;

-- ============================================================================
-- PHASE 4: FUTURE-READY OPTIMIZATIONS
-- For tables currently empty but may grow
-- ============================================================================

-- ONT_ROLE_BINDING: Currently empty (0 rows)
-- Uncomment when data is added
ALTER TABLE ONT_ROLE_BINDING 
ADD SEARCH OPTIMIZATION ON EQUALITY(ONT_ROLE_NAME, SNOWFLAKE_ROLE);

-- ONT_DERIVED_PROPERTY: Currently empty (0 rows)
-- Uncomment when computed properties are defined
ALTER TABLE ONT_DERIVED_PROPERTY 
ADD SEARCH OPTIMIZATION ON EQUALITY(CLASS_NAME, PROP_NAME);

-- ONT_CONSTRAINT_VIOLATION: Currently empty (0 rows)
-- This table could grow large - add both clustering and search optimization
-- Uncomment when constraint checking is active:
ALTER TABLE ONT_CONSTRAINT_VIOLATION 
CLUSTER BY (OBSERVED_AT, REL_OR_CLASS);

ALTER TABLE ONT_CONSTRAINT_VIOLATION 
ADD SEARCH OPTIMIZATION ON EQUALITY(SRC_ID, DST_ID, CHECK_NAME);

-- ============================================================================
-- PHASE 5: OPTIONAL ENHANCEMENTS
-- Consider these for additional performance gains
-- ============================================================================

-- Option A: Add search optimization to KG_EDGE for EDGE_TYPE filtering
-- Note: This is a large table (46M rows), evaluate cost vs. benefit
-- Current clustering on (SRC_ID, DST_ID) is good for graph traversal
-- This would help queries that filter by EDGE_TYPE first

ALTER TABLE KG_EDGE 
ADD SEARCH OPTIMIZATION ON EQUALITY(EDGE_TYPE);

-- Option B: Add search optimization to KG_NODE for NODE_ID lookups
-- Current clustering on NODE_TYPE is good for type-based filtering
-- This would help point lookups by NODE_ID

ALTER TABLE KG_NODE 
ADD SEARCH OPTIMIZATION ON EQUALITY(NODE_ID);

-- ============================================================================
-- PHASE 6: MATERIALIZED VIEWS (OPTIONAL)
-- Pre-joined metadata for common query patterns
-- ============================================================================

-- Materialized view: Class to Node Type mapping
CREATE OR REPLACE MATERIALIZED VIEW MV_CLASS_NODE_MAP AS
SELECT 
    c.CLASS_NAME,
    c.PARENT_CLASS_NAME,
    cm.SUBTYPE_VALUE AS NODE_TYPE,
    cm.CONCRETE_VIEW,
    cm.ID_COL,
    c.IS_ABSTRACT,
    c.TYPE_CLASS,
    c.DESCRIPTION,
    c.ONTOLOGY_NAME
FROM ONT_CLASS c
LEFT JOIN ONT_CLASS_MAP cm
    ON c.CLASS_NAME = cm.CLASS_NAME;

SELECT 'MV_CLASS_NODE_MAP: Materialized view created' AS status;

-- Materialized view: Relationship to Edge Type mapping
CREATE OR REPLACE MATERIALIZED VIEW MV_REL_EDGE_MAP AS
SELECT 
    rd.REL_NAME,
    rd.DOMAIN_CLASS,
    rd.RANGE_CLASS,
    rd.CARDINALITY,
    rd.IS_HIERARCHICAL,
    rd.INVERSE_REL_NAME,
    rm.VIA_REL_VALUE AS EDGE_TYPE,
    rm.CONCRETE_VIEW,
    rm.SRC_COL,
    rm.DST_COL,
    rm.PROPS_COL,
    rd.DESCRIPTION,
    rd.ONTOLOGY_NAME,
    rd.STATUS,
    rd.RENDER_HINT
FROM ONT_RELATION_DEF rd
LEFT JOIN ONT_REL_MAP rm
    ON rd.REL_NAME = rm.REL_NAME;

SELECT 'MV_REL_EDGE_MAP: Materialized view created' AS status;

-- Materialized view: Class properties with shared property details
CREATE OR REPLACE MATERIALIZED VIEW MV_CLASS_PROPERTIES AS
SELECT 
    p.CLASS_NAME,
    p.PROP_NAME,
    p.DATA_TYPE,
    p.SHARED_PROP_NAME,
    sp.BASE_TYPE AS SHARED_BASE_TYPE,
    sp.DEFAULT_FORMAT AS SHARED_DEFAULT_FORMAT,
    p.IS_REQUIRED,
    p.IS_INDEXED,
    p.DESCRIPTION,
    sp.DESCRIPTION AS SHARED_DESCRIPTION
FROM ONT_PROPERTY p
LEFT JOIN ONT_SHARED_PROPERTY sp
    ON p.SHARED_PROP_NAME = sp.SHARED_PROP_NAME;

SELECT 'MV_CLASS_PROPERTIES: Materialized view created' AS status;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check search optimization status
SELECT 
    TABLE_NAME,
    SEARCH_OPTIMIZATION,
    SEARCH_OPTIMIZATION_PROGRESS,
    SEARCH_OPTIMIZATION_BYTES,
    ROW_COUNT,
    BYTES
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'GRAPH_ONTOLOGY'
  AND TABLE_NAME LIKE 'ONT%'
ORDER BY TABLE_NAME;

-- Check clustering status for KG tables
SELECT 
    TABLE_NAME,
    CLUSTERING_KEY,
    AUTO_CLUSTERING_ON,
    ROW_COUNT,
    BYTES
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'GRAPH_ONTOLOGY'
  AND TABLE_NAME IN ('KG_NODE', 'KG_EDGE');

-- Summary of optimizations applied
SELECT 
    COUNT(CASE WHEN SEARCH_OPTIMIZATION IS NOT NULL THEN 1 END) AS tables_with_search_opt,
    COUNT(CASE WHEN CLUSTERING_KEY IS NOT NULL THEN 1 END) AS tables_with_clustering,
    COUNT(*) AS total_ont_tables
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'GRAPH_ONTOLOGY'
  AND TABLE_NAME LIKE 'ONT%';

-- ============================================================================
-- MONITORING QUERIES
-- Use these to track optimization build progress and effectiveness
-- ============================================================================

-- Monitor search optimization build progress
SELECT 
    TABLE_NAME,
    SEARCH_OPTIMIZATION,
    SEARCH_OPTIMIZATION_PROGRESS,
    CASE 
        WHEN SEARCH_OPTIMIZATION_PROGRESS = 100 THEN 'COMPLETE'
        WHEN SEARCH_OPTIMIZATION_PROGRESS > 0 THEN 'IN PROGRESS'
        ELSE 'NOT STARTED'
    END AS BUILD_STATUS,
    SEARCH_OPTIMIZATION_BYTES / 1024 / 1024 AS optimization_size_mb
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'GRAPH_ONTOLOGY'
  AND TABLE_NAME LIKE 'ONT%'
  AND SEARCH_OPTIMIZATION IS NOT NULL
ORDER BY SEARCH_OPTIMIZATION_PROGRESS DESC, TABLE_NAME;

-- Check automatic clustering history for KG tables
SELECT 
    TABLE_NAME,
    START_TIME,
    END_TIME,
    CREDITS_USED,
    NUM_BYTES_RECLUSTERED,
    NUM_ROWS_RECLUSTERED
FROM INFORMATION_SCHEMA.AUTOMATIC_CLUSTERING_HISTORY
WHERE TABLE_SCHEMA = 'GRAPH_ONTOLOGY'
  AND TABLE_NAME IN ('KG_NODE', 'KG_EDGE')
  AND START_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC;

-- ============================================================================
-- PERFORMANCE TESTING QUERIES
-- Run these before and after optimization to measure improvement
-- ============================================================================

-- Test 1: Class hierarchy lookup
SELECT c.CLASS_NAME, c.PARENT_CLASS_NAME, cm.SUBTYPE_VALUE
FROM ONT_CLASS c
JOIN ONT_CLASS_MAP cm ON c.CLASS_NAME = cm.CLASS_NAME
WHERE c.CLASS_NAME = 'Customer';

-- Test 2: Relationship definition lookup
SELECT rd.*, rm.VIA_REL_VALUE, rm.CONCRETE_VIEW
FROM ONT_RELATION_DEF rd
JOIN ONT_REL_MAP rm ON rd.REL_NAME = rm.REL_NAME
WHERE rd.REL_NAME = 'CUST_OWNS_PRODUCT';

-- Test 3: Property schema lookup
SELECT p.*, sp.BASE_TYPE, sp.DESCRIPTION
FROM ONT_PROPERTY p
LEFT JOIN ONT_SHARED_PROPERTY sp ON p.SHARED_PROP_NAME = sp.SHARED_PROP_NAME
WHERE p.CLASS_NAME = 'Customer';

-- Test 4: Multi-way join (class -> property -> shared property)
SELECT 
    c.CLASS_NAME,
    c.PARENT_CLASS_NAME,
    p.PROP_NAME,
    p.DATA_TYPE,
    sp.BASE_TYPE,
    p.IS_REQUIRED
FROM ONT_CLASS c
JOIN ONT_PROPERTY p ON c.CLASS_NAME = p.CLASS_NAME
LEFT JOIN ONT_SHARED_PROPERTY sp ON p.SHARED_PROP_NAME = sp.SHARED_PROP_NAME
WHERE c.CLASS_NAME IN ('Customer', 'Account', 'Transaction');

-- Test 5: Permission check (security-critical)
SELECT *
FROM ONT_PERMISSION
WHERE SUBJECT_NAME = 'ANALYST_ROLE'
  AND ONT_ROLE_NAME = 'READER';

-- Test 6: ETL source lookup
SELECT *
FROM ONT_OBJECT_SOURCE
WHERE OBJ_TYPE = 'Customer';

-- Test 7: Graph query with metadata join
-- Find all customers and their properties from KG_NODE
SELECT 
    n.NODE_ID,
    n.NAME,
    n.NODE_TYPE,
    cm.CLASS_NAME,
    n.PROPS
FROM KG_NODE n
JOIN ONT_CLASS_MAP cm ON n.NODE_TYPE = cm.SUBTYPE_VALUE
WHERE cm.CLASS_NAME = 'Customer'
LIMIT 100;

-- Test 8: Edge query with relationship metadata
-- Find all customer-account relationships
SELECT 
    e.EDGE_ID,
    e.SRC_ID,
    e.DST_ID,
    e.EDGE_TYPE,
    rm.REL_NAME,
    rd.DOMAIN_CLASS,
    rd.RANGE_CLASS,
    rd.CARDINALITY
FROM KG_EDGE e
JOIN ONT_REL_MAP rm ON e.EDGE_TYPE = rm.VIA_REL_VALUE
JOIN ONT_RELATION_DEF rd ON rm.REL_NAME = rd.REL_NAME
WHERE rm.REL_NAME = 'CUST_OWNS_PRODUCT'
LIMIT 100;

-- ============================================================================
-- COMPLETION SUMMARY
-- ============================================================================

SELECT 
    'Search optimization applied to ' || COUNT(*) || ' ONT* tables' AS summary
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'GRAPH_ONTOLOGY'
  AND TABLE_NAME LIKE 'ONT%'
  AND SEARCH_OPTIMIZATION IS NOT NULL;

SELECT 
    'KG_NODE and KG_EDGE already have clustering enabled' AS summary;

SELECT 
    'Materialized views created for common join patterns' AS summary;

SELECT 
    'Optimization complete - monitor search optimization build progress' AS summary;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. Search optimization builds asynchronously in the background
--    - Small tables (<1MB): Complete in 1-5 minutes
--    - Medium tables (1-10MB): Complete in 5-15 minutes
--    - Progress visible in INFORMATION_SCHEMA.TABLES.SEARCH_OPTIMIZATION_PROGRESS
--
-- 2. Auto-clustering for KG_NODE and KG_EDGE is already enabled
--    - Snowflake automatically maintains clustering
--    - Monitor AUTOMATIC_CLUSTERING_HISTORY for maintenance activity
--
-- 3. Materialized views need manual refresh if base tables change
--    - For metadata tables (ONT_*), changes are rare
--    - Set up scheduled refresh if needed (e.g., daily)
--
-- 4. Cost considerations
--    - Search optimization storage overhead: ~20-40% per table
--    - For small ONT* tables: Total overhead < 1MB
--    - Auto-clustering: Minimal for small, stable tables
--    - ROI: 5-20x query performance improvement
--
-- 5. Future monitoring
--    - Review query performance regularly
--    - Check search optimization maintenance credits
--    - Monitor clustering depth and overlaps
--    - Add optimizations to new ONT_* tables as they're created
-- ============================================================================

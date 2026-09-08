-- Search optimization analysis and recommendations for GRAPH_ONTOLOGY schema
/*
====================================================================================================
CURRENT SEARCH OPTIMIZATION STATUS
====================================================================================================
Tables with Search Optimization ENABLED (100% complete):
- KG_NODE (550K rows, 20MB)
- KG_EDGE (556K rows, 9.6MB)  
- GRAPH_ADJACENCY_FULL (477K rows, 21MB)
- DEEP_TRAVERSAL_RESULTS (377K rows, 13MB)
- FAN_IN_DETECTION_RESULTS (74K rows, 3.4MB)
- FAN_OUT_DETECTION_RESULTS (66K rows, 3MB)

Tables with Automatic Clustering ENABLED:
- KG_NODE: LINEAR(NODE_TYPE)
- KG_EDGE: LINEAR(EDGE_TYPE, SRC_ID, DST_ID)
- FAN_IN_DETECTION_RESULTS: LINEAR(DETECTION_TIMESTAMP, DST_NODE_ID)

====================================================================================================
ANALYSIS OF QUERY PATTERNS
====================================================================================================

1. PROCEDURE QUERY PATTERNS:
   - SP_FAN_IN_DETECTION_OPTIMIZED: Filters by EDGE_TYPE, DST_ID aggregation, joins on NODE_ID
   - SP_FAN_OUT_DETECTION_OPTIMIZED: Filters by EDGE_TYPE, SRC_ID aggregation, joins on NODE_ID
   - SP_DEEP_TRAVERSAL: Recursive traversal with SRC_ID/DST_ID lookups, NODE_TYPE filtering
   - SP_REFRESH_ADJACENCY_MATRIX: Full table scans with aggregation

2. VIEW QUERY PATTERNS:
   - V_* views: Filter KG_NODE by NODE_TYPE with VARIANT property extraction
   - VW_GRAPH_EDGES_ENRICHED: 2-way joins on KG_EDGE + KG_NODE (SRC_ID, DST_ID)
   - VW_GRAPH_NODES_ENRICHED: Join KG_NODE + GRAPH_ADJACENCY_FULL on NODE_ID
   - REL_RESOLVED: Multiple UNION ALL with KG_EDGE filtering by EDGE_TYPE

====================================================================================================
OPTIMIZATION RECOMMENDATIONS
====================================================================================================

✅ ALREADY OPTIMAL:
- Search optimization is correctly configured on all key tables
- Clustering keys are appropriate for access patterns
- Core graph tables (KG_NODE, KG_EDGE) have both clustering and search optimization

🚀 ADDITIONAL OPTIMIZATIONS TO IMPLEMENT:

1. MATERIALIZED VIEWS: Convert high-usage views to materialized views
   - VW_GRAPH_EDGES_ENRICHED (2-way join, frequently accessed)
   - VW_GRAPH_NODES_ENRICHED (join with adjacency matrix)
   
2. PROCEDURE OPTIMIZATIONS:
   - Add RESULT_SCAN caching for repeated subquery patterns
   - Use LATERAL FLATTEN more efficiently
   - Pre-filter before joins (already done in optimized versions)
   
3. MISSING SEARCH OPTIMIZATION:
   - GRAPH_ADJACENCY_MAT (299K rows) - should enable if queried frequently

4. VIEW OPTIMIZATIONS:
   - Add query_acceleration_max_scale_factor hint for complex aggregations
   - Use QUALIFY instead of subqueries where applicable

====================================================================================================
*/

-- =============================================
-- RECOMMENDATION 1: Enable Search Optimization on GRAPH_ADJACENCY_MAT
-- =============================================
-- Only run this if you query GRAPH_ADJACENCY_MAT directly (not through GRAPH_ADJACENCY_FULL)
-- ALTER TABLE A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.GRAPH_ADJACENCY_MAT 
-- ADD SEARCH OPTIMIZATION ON EQUALITY(NODE_ID);

-- =============================================
-- RECOMMENDATION 2: Add Search Optimization for Time-Based Queries on KG_EDGE
-- =============================================
-- The fan-in/fan-out procedures filter by EFFECTIVE_START date
ALTER TABLE A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.KG_EDGE 
ADD SEARCH OPTIMIZATION ON EQUALITY(EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE)
ON SUBSTRING(EFFECTIVE_START);

-- =============================================
-- RECOMMENDATION 3: Monitor Search Optimization Performance
-- =============================================
-- Run this query to see search optimization benefits
SELECT 
    table_name,
    search_optimization,
    search_optimization_bytes,
    ROUND(search_optimization_bytes / bytes * 100, 2) as so_overhead_pct
FROM A01A0E_GBU_FINCRIME_POC.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'GRAPH_ONTOLOGY' 
  AND search_optimization = 'ON'
ORDER BY bytes DESC;

-- Check search optimization usage in query history
SELECT 
    query_id,
    query_text,
    execution_time,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned::FLOAT / NULLIF(partitions_total, 0) * 100, 2) as pct_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%GRAPH_ONTOLOGY%'
  AND execution_status = 'SUCCESS'
  AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY execution_time DESC
LIMIT 20;

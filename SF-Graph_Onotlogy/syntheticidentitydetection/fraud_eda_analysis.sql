-- Comprehensive exploratory data analysis for fraud detection ML model

USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;

-- ============================================================================
-- 1. BASIC STATISTICS
-- ============================================================================
SELECT '=== BASIC STATISTICS ===' AS section;

SELECT 
    IS_FRAUD,
    COUNT(*) AS transaction_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage,
    ROUND(MIN(AMOUNT), 2) AS min_amount,
    ROUND(AVG(AMOUNT), 2) AS avg_amount,
    ROUND(MEDIAN(AMOUNT), 2) AS median_amount,
    ROUND(STDDEV(AMOUNT), 2) AS stddev_amount,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY AMOUNT), 2) AS q1_amount,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY AMOUNT), 2) AS q3_amount,
    ROUND(MAX(AMOUNT), 2) AS max_amount
FROM FRAUD_ML_TEST_ONLINE
GROUP BY IS_FRAUD
ORDER BY IS_FRAUD;

-- ============================================================================
-- 2. MERCHANT ANALYSIS
-- ============================================================================
SELECT '=== MERCHANT FRAUD RATES ===' AS section;

SELECT 
    MERCHANT,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(AVG(AMOUNT), 2) AS avg_amount,
    ROUND(AVG(CASE WHEN IS_FRAUD THEN AMOUNT END), 2) AS avg_fraud_amount,
    ROUND(AVG(CASE WHEN NOT IS_FRAUD THEN AMOUNT END), 2) AS avg_legit_amount
FROM FRAUD_ML_TEST_ONLINE
GROUP BY MERCHANT
ORDER BY fraud_rate_pct DESC, total_transactions DESC;

-- ============================================================================
-- 3. LOCATION ANALYSIS
-- ============================================================================
SELECT '=== LOCATION FRAUD RATES ===' AS section;

SELECT 
    LOCATION,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(AVG(AMOUNT), 2) AS avg_amount
FROM FRAUD_ML_TEST_ONLINE
GROUP BY LOCATION
ORDER BY fraud_rate_pct DESC;

-- ============================================================================
-- 4. TIME PATTERN ANALYSIS - HOUR OF DAY
-- ============================================================================
SELECT '=== HOURLY FRAUD PATTERNS ===' AS section;

SELECT 
    HOUR(TRANSACTION_TIME) AS hour_of_day,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    CASE 
        WHEN HOUR(TRANSACTION_TIME) BETWEEN 0 AND 5 THEN 'Late Night (12-6 AM)'
        WHEN HOUR(TRANSACTION_TIME) BETWEEN 6 AND 11 THEN 'Morning (6-12 AM)'
        WHEN HOUR(TRANSACTION_TIME) BETWEEN 12 AND 17 THEN 'Afternoon (12-6 PM)'
        WHEN HOUR(TRANSACTION_TIME) BETWEEN 18 AND 21 THEN 'Evening (6-10 PM)'
        ELSE 'Night (10 PM-12 AM)'
    END AS time_period
FROM FRAUD_ML_TEST_ONLINE
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- ============================================================================
-- 5. TIME PATTERN ANALYSIS - DAY OF WEEK
-- ============================================================================
SELECT '=== DAY OF WEEK FRAUD PATTERNS ===' AS section;

SELECT 
    DAYOFWEEK(TRANSACTION_TIME) AS day_num,
    DAYNAME(TRANSACTION_TIME) AS day_name,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    CASE 
        WHEN DAYOFWEEK(TRANSACTION_TIME) IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END AS week_part
FROM FRAUD_ML_TEST_ONLINE
GROUP BY day_num, day_name
ORDER BY day_num;

-- ============================================================================
-- 6. AMOUNT RANGE ANALYSIS
-- ============================================================================
SELECT '=== AMOUNT RANGE FRAUD RATES ===' AS section;

SELECT 
    CASE 
        WHEN AMOUNT < 50 THEN '1: $0-50'
        WHEN AMOUNT < 100 THEN '2: $50-100'
        WHEN AMOUNT < 250 THEN '3: $100-250'
        WHEN AMOUNT < 500 THEN '4: $250-500'
        WHEN AMOUNT < 1000 THEN '5: $500-1K'
        WHEN AMOUNT < 2500 THEN '6: $1K-2.5K'
        WHEN AMOUNT < 5000 THEN '7: $2.5K-5K'
        ELSE '8: $5K+'
    END AS amount_range,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM FRAUD_ML_TEST_ONLINE
GROUP BY amount_range
ORDER BY amount_range;

-- ============================================================================
-- 7. HIGH-RISK COMBINATIONS (MERCHANT + LOCATION)
-- ============================================================================
SELECT '=== HIGH-RISK MERCHANT-LOCATION COMBINATIONS ===' AS section;

SELECT 
    MERCHANT,
    LOCATION,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(AVG(AMOUNT), 2) AS avg_amount
FROM FRAUD_ML_TEST_ONLINE
GROUP BY MERCHANT, LOCATION
HAVING COUNT(*) >= 5
ORDER BY fraud_rate_pct DESC, total_transactions DESC
LIMIT 30;

-- ============================================================================
-- 8. TIME-BASED RISK COMBINATIONS
-- ============================================================================
SELECT '=== TIME + AMOUNT RISK PATTERNS ===' AS section;

SELECT 
    CASE 
        WHEN HOUR(TRANSACTION_TIME) BETWEEN 0 AND 5 THEN 'Late Night'
        WHEN HOUR(TRANSACTION_TIME) BETWEEN 6 AND 21 THEN 'Business Hours'
        ELSE 'Night'
    END AS time_period,
    CASE 
        WHEN AMOUNT < 500 THEN 'Low ($0-500)'
        WHEN AMOUNT < 2000 THEN 'Medium ($500-2K)'
        ELSE 'High ($2K+)'
    END AS amount_category,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM FRAUD_ML_TEST_ONLINE
GROUP BY time_period, amount_category
ORDER BY fraud_rate_pct DESC;

-- ============================================================================
-- 9. CORRELATION ANALYSIS - SUSPICIOUS PATTERNS
-- ============================================================================
SELECT '=== SUSPICIOUS PATTERN DISTRIBUTION ===' AS section;

SELECT 
    FRAUD_PATTERN,
    IS_FRAUD,
    COUNT(*) AS count,
    ROUND(AVG(AMOUNT), 2) AS avg_amount,
    ROUND(MEDIAN(AMOUNT), 2) AS median_amount
FROM FRAUD_ML_TEST_ONLINE
GROUP BY FRAUD_PATTERN, IS_FRAUD
ORDER BY IS_FRAUD DESC, FRAUD_PATTERN;

-- ============================================================================
-- 10. FEATURE IMPORTANCE INDICATORS
-- ============================================================================
SELECT '=== FEATURE IMPORTANCE INDICATORS ===' AS section;

WITH fraud_stats AS (
    SELECT 
        COUNT(*) AS total_fraud,
        AVG(AMOUNT) AS avg_fraud_amount
    FROM FRAUD_ML_TEST_ONLINE
    WHERE IS_FRAUD = TRUE
),
legit_stats AS (
    SELECT 
        COUNT(*) AS total_legit,
        AVG(AMOUNT) AS avg_legit_amount
    FROM FRAUD_ML_TEST_ONLINE
    WHERE IS_FRAUD = FALSE
)
SELECT 
    'Amount Difference' AS feature,
    ROUND((SELECT avg_fraud_amount FROM fraud_stats), 2) AS fraud_avg,
    ROUND((SELECT avg_legit_amount FROM legit_stats), 2) AS legit_avg,
    ROUND((SELECT avg_fraud_amount FROM fraud_stats) - (SELECT avg_legit_amount FROM legit_stats), 2) AS difference
UNION ALL
SELECT 
    'High-Risk Merchants (>2% fraud rate)',
    (SELECT COUNT(DISTINCT MERCHANT) 
     FROM (SELECT MERCHANT, SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS fr 
           FROM FRAUD_ML_TEST_ONLINE GROUP BY MERCHANT HAVING fr > 2)),
    NULL,
    NULL
UNION ALL
SELECT 
    'High-Risk Locations (>2% fraud rate)',
    (SELECT COUNT(DISTINCT LOCATION) 
     FROM (SELECT LOCATION, SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS fr 
           FROM FRAUD_ML_TEST_ONLINE GROUP BY LOCATION HAVING fr > 2)),
    NULL,
    NULL;

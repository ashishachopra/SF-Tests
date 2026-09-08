-- Feature engineering for fraud detection ML model

USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;

-- ============================================================================
-- CREATE ML-READY FEATURE TABLE
-- ============================================================================

CREATE OR REPLACE TABLE FRAUD_ML_FEATURES AS
WITH 
-- Merchant statistics (fraud rates, transaction volumes)
merchant_stats AS (
    SELECT 
        MERCHANT,
        COUNT(*) AS merchant_total_txns,
        SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS merchant_fraud_count,
        ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) AS merchant_fraud_rate,
        ROUND(AVG(AMOUNT), 2) AS merchant_avg_amount,
        ROUND(STDDEV(AMOUNT), 2) AS merchant_stddev_amount
    FROM FRAUD_ML_TEST_ONLINE
    GROUP BY MERCHANT
),
-- Location statistics
location_stats AS (
    SELECT 
        LOCATION,
        COUNT(*) AS location_total_txns,
        SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS location_fraud_count,
        ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) AS location_fraud_rate,
        ROUND(AVG(AMOUNT), 2) AS location_avg_amount
    FROM FRAUD_ML_TEST_ONLINE
    GROUP BY LOCATION
),
-- Merchant-Location combination statistics
merchant_location_stats AS (
    SELECT 
        MERCHANT,
        LOCATION,
        COUNT(*) AS combo_total_txns,
        SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) AS combo_fraud_count,
        ROUND(SUM(CASE WHEN IS_FRAUD THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 4) AS combo_fraud_rate
    FROM FRAUD_ML_TEST_ONLINE
    GROUP BY MERCHANT, LOCATION
)
SELECT 
    t.TRANSACTION_ID,
    
    -- ==================== TARGET VARIABLE ====================
    t.IS_FRAUD AS target,
    
    -- ==================== TRANSACTION AMOUNT FEATURES ====================
    t.AMOUNT AS amount,
    LN(t.AMOUNT + 1) AS amount_log,
    CASE 
        WHEN t.AMOUNT < 50 THEN 1
        WHEN t.AMOUNT < 100 THEN 2
        WHEN t.AMOUNT < 250 THEN 3
        WHEN t.AMOUNT < 500 THEN 4
        WHEN t.AMOUNT < 1000 THEN 5
        WHEN t.AMOUNT < 2500 THEN 6
        WHEN t.AMOUNT < 5000 THEN 7
        ELSE 8
    END AS amount_category,
    CASE WHEN t.AMOUNT > 1000 THEN 1 ELSE 0 END AS is_high_amount,
    CASE WHEN t.AMOUNT > 2500 THEN 1 ELSE 0 END AS is_very_high_amount,
    
    -- ==================== TIME FEATURES ====================
    t.TRANSACTION_TIME,
    HOUR(t.TRANSACTION_TIME) AS hour_of_day,
    DAYOFWEEK(t.TRANSACTION_TIME) AS day_of_week,
    CASE WHEN DAYOFWEEK(t.TRANSACTION_TIME) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend,
    CASE 
        WHEN HOUR(t.TRANSACTION_TIME) BETWEEN 0 AND 5 THEN 1 
        ELSE 0 
    END AS is_late_night,
    CASE 
        WHEN HOUR(t.TRANSACTION_TIME) BETWEEN 22 AND 23 
        OR HOUR(t.TRANSACTION_TIME) BETWEEN 0 AND 5 THEN 1 
        ELSE 0 
    END AS is_odd_hours,
    CASE 
        WHEN HOUR(t.TRANSACTION_TIME) BETWEEN 9 AND 17 THEN 1 
        ELSE 0 
    END AS is_business_hours,
    
    -- ==================== MERCHANT FEATURES ====================
    t.MERCHANT AS merchant_name,
    -- Merchant risk indicators
    ms.merchant_fraud_rate,
    ms.merchant_total_txns,
    ms.merchant_avg_amount,
    ms.merchant_stddev_amount,
    CASE WHEN ms.merchant_fraud_rate > 2.0 THEN 1 ELSE 0 END AS is_high_risk_merchant,
    CASE WHEN ms.merchant_fraud_rate > 5.0 THEN 1 ELSE 0 END AS is_very_high_risk_merchant,
    -- Amount deviation from merchant average
    ROUND(t.AMOUNT - ms.merchant_avg_amount, 2) AS amount_deviation_from_merchant_avg,
    ROUND((t.AMOUNT - ms.merchant_avg_amount) / NULLIF(ms.merchant_stddev_amount, 0), 2) AS amount_zscore_merchant,
    CASE WHEN t.AMOUNT > ms.merchant_avg_amount + (2 * ms.merchant_stddev_amount) THEN 1 ELSE 0 END AS is_outlier_amount_for_merchant,
    -- Merchant category encoding
    CASE 
        WHEN t.MERCHANT IN ('Bitcoin ATM Network', 'Wire Transfer Service', 'Offshore Gaming Co', 
                            'Luxury Jewelers Ltd', 'Premium Electronics Export') THEN 1 
        ELSE 0 
    END AS is_uncommon_merchant,
    
    -- ==================== LOCATION FEATURES ====================
    t.LOCATION AS location_name,
    ls.location_fraud_rate,
    ls.location_total_txns,
    ls.location_avg_amount,
    CASE WHEN ls.location_fraud_rate > 2.0 THEN 1 ELSE 0 END AS is_high_risk_location,
    CASE WHEN ls.location_fraud_rate > 5.0 THEN 1 ELSE 0 END AS is_very_high_risk_location,
    -- Location category encoding
    CASE 
        WHEN t.LOCATION IN ('Lagos, Nigeria', 'Moscow, Russia', 'Jakarta, Indonesia', 
                            'Manila, Philippines', 'Unknown Location') THEN 1 
        ELSE 0 
    END AS is_international_suspicious,
    CASE WHEN t.LOCATION = 'Unknown Location' THEN 1 ELSE 0 END AS is_unknown_location,
    
    -- ==================== MERCHANT-LOCATION COMBINATION FEATURES ====================
    mls.combo_fraud_rate AS merchant_location_fraud_rate,
    mls.combo_total_txns AS merchant_location_total_txns,
    CASE WHEN mls.combo_fraud_rate > 5.0 THEN 1 ELSE 0 END AS is_high_risk_combo,
    
    -- ==================== INTERACTION FEATURES ====================
    -- High amount + odd hours
    CASE WHEN t.AMOUNT > 1000 AND HOUR(t.TRANSACTION_TIME) NOT BETWEEN 6 AND 21 THEN 1 ELSE 0 END AS high_amount_odd_hours,
    -- Uncommon merchant + suspicious location
    CASE 
        WHEN t.MERCHANT IN ('Bitcoin ATM Network', 'Wire Transfer Service', 'Offshore Gaming Co') 
        AND t.LOCATION IN ('Lagos, Nigeria', 'Moscow, Russia', 'Jakarta, Indonesia', 'Manila, Philippines', 'Unknown Location')
        THEN 1 ELSE 0 
    END AS uncommon_merchant_suspicious_location,
    -- High amount + suspicious location
    CASE WHEN t.AMOUNT > 2000 AND ls.location_fraud_rate > 5.0 THEN 1 ELSE 0 END AS high_amount_risky_location,
    -- Weekend + late night
    CASE 
        WHEN DAYOFWEEK(t.TRANSACTION_TIME) IN (0, 6) 
        AND HOUR(t.TRANSACTION_TIME) BETWEEN 0 AND 5 THEN 1 ELSE 0 
    END AS weekend_late_night,
    
    -- ==================== VELOCITY/FREQUENCY FEATURES (PLACEHOLDER) ====================
    -- Note: These would require window functions over customer/card data if available
    -- Examples for future enhancement:
    -- - transactions_last_hour
    -- - transactions_last_24_hours
    -- - unique_merchants_last_24_hours
    -- - unique_locations_last_24_hours
    -- - total_amount_last_hour
    -- - avg_time_between_transactions
    
    -- ==================== ANOMALY SCORE FEATURES ====================
    -- Simple anomaly indicators
    CASE 
        WHEN (t.AMOUNT > 5000) 
        OR (HOUR(t.TRANSACTION_TIME) BETWEEN 0 AND 5) 
        OR (t.LOCATION IN ('Lagos, Nigeria', 'Moscow, Russia', 'Unknown Location'))
        OR (t.MERCHANT IN ('Bitcoin ATM Network', 'Wire Transfer Service'))
        THEN 1 ELSE 0 
    END AS has_any_suspicious_indicator,
    
    -- Count of suspicious indicators
    (CASE WHEN t.AMOUNT > 2000 THEN 1 ELSE 0 END +
     CASE WHEN HOUR(t.TRANSACTION_TIME) NOT BETWEEN 6 AND 21 THEN 1 ELSE 0 END +
     CASE WHEN ms.merchant_fraud_rate > 2.0 THEN 1 ELSE 0 END +
     CASE WHEN ls.location_fraud_rate > 2.0 THEN 1 ELSE 0 END +
     CASE WHEN t.MERCHANT IN ('Bitcoin ATM Network', 'Wire Transfer Service', 'Offshore Gaming Co') THEN 1 ELSE 0 END +
     CASE WHEN t.LOCATION IN ('Lagos, Nigeria', 'Moscow, Russia', 'Jakarta, Indonesia', 'Unknown Location') THEN 1 ELSE 0 END
    ) AS suspicious_indicator_count

FROM FRAUD_ML_TEST_ONLINE t
LEFT JOIN merchant_stats ms ON t.MERCHANT = ms.MERCHANT
LEFT JOIN location_stats ls ON t.LOCATION = ls.LOCATION
LEFT JOIN merchant_location_stats mls ON t.MERCHANT = mls.MERCHANT AND t.LOCATION = mls.LOCATION;

-- ============================================================================
-- VERIFY FEATURE TABLE
-- ============================================================================
SELECT 'Feature table created successfully' AS status;
SELECT COUNT(*) AS total_rows FROM FRAUD_ML_FEATURES;

-- Sample of features
SELECT * FROM FRAUD_ML_FEATURES LIMIT 5;

-- ============================================================================
-- FEATURE CORRELATION WITH FRAUD
-- ============================================================================
SELECT 'High-risk merchant fraud correlation' AS analysis;
SELECT 
    is_high_risk_merchant,
    COUNT(*) AS total,
    SUM(target::INT) AS fraud_count,
    ROUND(SUM(target::INT) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM FRAUD_ML_FEATURES
GROUP BY is_high_risk_merchant;

SELECT 'High-risk location fraud correlation' AS analysis;
SELECT 
    is_high_risk_location,
    COUNT(*) AS total,
    SUM(target::INT) AS fraud_count,
    ROUND(SUM(target::INT) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM FRAUD_ML_FEATURES
GROUP BY is_high_risk_location;

SELECT 'Odd hours fraud correlation' AS analysis;
SELECT 
    is_odd_hours,
    COUNT(*) AS total,
    SUM(target::INT) AS fraud_count,
    ROUND(SUM(target::INT) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM FRAUD_ML_FEATURES
GROUP BY is_odd_hours;

SELECT 'Suspicious indicator count analysis' AS analysis;
SELECT 
    suspicious_indicator_count,
    COUNT(*) AS total,
    SUM(target::INT) AS fraud_count,
    ROUND(SUM(target::INT) * 100.0 / COUNT(*), 2) AS fraud_rate_pct
FROM FRAUD_ML_FEATURES
GROUP BY suspicious_indicator_count
ORDER BY suspicious_indicator_count;

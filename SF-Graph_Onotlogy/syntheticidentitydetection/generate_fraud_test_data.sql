-- Generate synthetic financial transaction data with realistic fraud patterns and noise

USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;

-- Drop table if exists
DROP TABLE IF EXISTS FRAUD_ML_TEST_ONLINE;

-- Create the table structure
CREATE TABLE FRAUD_ML_TEST_ONLINE (
    TRANSACTION_ID VARCHAR(50) PRIMARY KEY,
    TRANSACTION_TIME TIMESTAMP_NTZ,
    AMOUNT DECIMAL(10,2),
    MERCHANT VARCHAR(100),
    LOCATION VARCHAR(100),
    IS_FRAUD BOOLEAN,
    FRAUD_PATTERN VARCHAR(50) -- For analysis: 'NORMAL_FRAUD', 'SUSPICIOUS_FRAUD', 'NORMAL_LEGIT', 'SUSPICIOUS_LEGIT'
);

-- Generate 100,000 transactions with realistic fraud patterns
INSERT INTO FRAUD_ML_TEST_ONLINE
WITH 
-- Define merchant categories
merchants AS (
    SELECT * FROM (VALUES
        ('Amazon.com', 'E-commerce', 'Common'),
        ('Walmart', 'Retail', 'Common'),
        ('Target', 'Retail', 'Common'),
        ('Starbucks', 'Coffee', 'Common'),
        ('Shell Gas Station', 'Gas', 'Common'),
        ('McDonald''s', 'Fast Food', 'Common'),
        ('Netflix', 'Subscription', 'Common'),
        ('Apple Store', 'Electronics', 'Common'),
        ('Uber', 'Transportation', 'Common'),
        ('CVS Pharmacy', 'Pharmacy', 'Common'),
        ('Best Buy', 'Electronics', 'Common'),
        ('Home Depot', 'Home Improvement', 'Common'),
        ('Chipotle', 'Restaurant', 'Common'),
        ('Costco', 'Wholesale', 'Common'),
        ('Whole Foods', 'Grocery', 'Common'),
        ('Luxury Jewelers Ltd', 'Jewelry', 'Uncommon'),
        ('Bitcoin ATM Network', 'Crypto', 'Uncommon'),
        ('Wire Transfer Service', 'Money Transfer', 'Uncommon'),
        ('Offshore Gaming Co', 'Gambling', 'Uncommon'),
        ('Premium Electronics Export', 'Electronics', 'Uncommon')
    ) AS t(merchant_name, category, frequency)
),
-- Define locations
locations AS (
    SELECT * FROM (VALUES
        ('New York, NY', 'Domestic', 'Common'),
        ('Los Angeles, CA', 'Domestic', 'Common'),
        ('Chicago, IL', 'Domestic', 'Common'),
        ('Houston, TX', 'Domestic', 'Common'),
        ('Phoenix, AZ', 'Domestic', 'Common'),
        ('Philadelphia, PA', 'Domestic', 'Common'),
        ('San Antonio, TX', 'Domestic', 'Common'),
        ('San Diego, CA', 'Domestic', 'Common'),
        ('Dallas, TX', 'Domestic', 'Common'),
        ('San Jose, CA', 'Domestic', 'Common'),
        ('Austin, TX', 'Domestic', 'Common'),
        ('Seattle, WA', 'Domestic', 'Common'),
        ('Denver, CO', 'Domestic', 'Common'),
        ('Miami, FL', 'Domestic', 'Common'),
        ('Atlanta, GA', 'Domestic', 'Common'),
        ('Lagos, Nigeria', 'International', 'Suspicious'),
        ('Moscow, Russia', 'International', 'Suspicious'),
        ('Jakarta, Indonesia', 'International', 'Suspicious'),
        ('Manila, Philippines', 'International', 'Suspicious'),
        ('Unknown Location', 'Unknown', 'Suspicious')
    ) AS t(location_name, region, risk_level)
),
-- Generate base transactions
base_transactions AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS transaction_num,
        UNIFORM(1, 100000, RANDOM()) AS rand_seed,
        -- Determine if fraud (0.5% = 500 out of 100,000)
        CASE WHEN UNIFORM(1, 10000, RANDOM()) <= 50 THEN TRUE ELSE FALSE END AS is_fraud_flag
    FROM TABLE(GENERATOR(ROWCOUNT => 100000))
),
-- Assign fraud patterns with noise
transactions_with_patterns AS (
    SELECT
        transaction_num,
        rand_seed,
        is_fraud_flag,
        -- For fraudulent transactions: 1/3 should look normal, 2/3 suspicious
        CASE 
            WHEN is_fraud_flag = TRUE THEN
                CASE WHEN UNIFORM(1, 3, RANDOM(rand_seed)) = 1 
                    THEN 'NORMAL_FRAUD' 
                    ELSE 'SUSPICIOUS_FRAUD' 
                END
            -- For legitimate transactions: 2% should look suspicious
            WHEN is_fraud_flag = FALSE THEN
                CASE WHEN UNIFORM(1, 100, RANDOM(rand_seed + 1)) <= 2
                    THEN 'SUSPICIOUS_LEGIT'
                    ELSE 'NORMAL_LEGIT'
                END
        END AS fraud_pattern
    FROM base_transactions
)
SELECT
    'TXN_' || LPAD(t.transaction_num::VARCHAR, 8, '0') AS TRANSACTION_ID,
    
    -- Transaction time: Most between 6 AM - 11 PM, but suspicious ones often at odd hours
    DATEADD(
        MINUTE,
        CASE 
            WHEN t.fraud_pattern IN ('SUSPICIOUS_FRAUD', 'SUSPICIOUS_LEGIT') 
                AND UNIFORM(1, 100, RANDOM(t.rand_seed + 2)) <= 60 -- 60% of suspicious at odd hours
            THEN UNIFORM(0, 360, RANDOM(t.rand_seed + 3)) + UNIFORM(1320, 1440, RANDOM(t.rand_seed + 4)) -- 12 AM - 6 AM or 10 PM - 12 AM
            ELSE UNIFORM(360, 1380, RANDOM(t.rand_seed + 5)) -- 6 AM - 11 PM
        END,
        DATEADD(
            DAY, 
            -UNIFORM(0, 90, RANDOM(t.rand_seed + 6)),  -- Last 90 days
            CURRENT_TIMESTAMP()
        )
    ) AS TRANSACTION_TIME,
    
    -- Amount: Fraudulent tend to be higher, but add noise
    CASE
        -- Normal-looking fraud: typical amounts ($10-$500)
        WHEN t.fraud_pattern = 'NORMAL_FRAUD' 
        THEN ROUND(POWER(UNIFORM(1, 100, RANDOM(t.rand_seed + 7)) / 100.0, 2) * 490 + 10, 2)
        
        -- Suspicious fraud: high amounts ($500-$9999)
        WHEN t.fraud_pattern = 'SUSPICIOUS_FRAUD'
        THEN ROUND(POWER(UNIFORM(1, 100, RANDOM(t.rand_seed + 8)) / 100.0, 1.5) * 9499 + 500, 2)
        
        -- Suspicious legit: higher than normal but legitimate ($300-$2000)
        WHEN t.fraud_pattern = 'SUSPICIOUS_LEGIT'
        THEN ROUND(POWER(UNIFORM(1, 100, RANDOM(t.rand_seed + 9)) / 100.0, 2) * 1700 + 300, 2)
        
        -- Normal legit: typical amounts ($5-$500)
        ELSE ROUND(POWER(UNIFORM(1, 100, RANDOM(t.rand_seed + 10)) / 100.0, 2.5) * 495 + 5, 2)
    END AS AMOUNT,
    
    -- Merchant: Suspicious transactions use uncommon merchants more often
    CASE
        WHEN t.fraud_pattern IN ('SUSPICIOUS_FRAUD', 'SUSPICIOUS_LEGIT')
            AND UNIFORM(1, 100, RANDOM(t.rand_seed + 11)) <= 70 -- 70% use uncommon merchants
        THEN (SELECT merchant_name FROM merchants WHERE frequency = 'Uncommon' 
              ORDER BY RANDOM(t.rand_seed + 12) LIMIT 1)
        ELSE (SELECT merchant_name FROM merchants WHERE frequency = 'Common' 
              ORDER BY RANDOM(t.rand_seed + 13) LIMIT 1)
    END AS MERCHANT,
    
    -- Location: Suspicious transactions more likely in risky locations
    CASE
        WHEN t.fraud_pattern IN ('SUSPICIOUS_FRAUD', 'SUSPICIOUS_LEGIT')
            AND UNIFORM(1, 100, RANDOM(t.rand_seed + 14)) <= 50 -- 50% in suspicious locations
        THEN (SELECT location_name FROM locations WHERE risk_level = 'Suspicious' 
              ORDER BY RANDOM(t.rand_seed + 15) LIMIT 1)
        ELSE (SELECT location_name FROM locations WHERE risk_level = 'Common' 
              ORDER BY RANDOM(t.rand_seed + 16) LIMIT 1)
    END AS LOCATION,
    
    -- Actual fraud flag
    t.is_fraud_flag AS IS_FRAUD,
    
    -- Pattern for analysis
    t.fraud_pattern AS FRAUD_PATTERN
    
FROM transactions_with_patterns t;

-- Display summary statistics
SELECT 
    'Total Transactions' AS metric,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / 100000, 2) AS percentage
FROM FRAUD_ML_TEST_ONLINE
UNION ALL
SELECT 
    'Fraudulent Transactions',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 / 100000, 2)
FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = TRUE
UNION ALL
SELECT 
    'Legitimate Transactions',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 / 100000, 2)
FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = FALSE
UNION ALL
SELECT 
    'Normal-Looking Fraud',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = TRUE), 2)
FROM FRAUD_ML_TEST_ONLINE WHERE FRAUD_PATTERN = 'NORMAL_FRAUD'
UNION ALL
SELECT 
    'Suspicious-Looking Fraud',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = TRUE), 2)
FROM FRAUD_ML_TEST_ONLINE WHERE FRAUD_PATTERN = 'SUSPICIOUS_FRAUD'
UNION ALL
SELECT 
    'Suspicious-Looking Legit',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = FALSE), 2)
FROM FRAUD_ML_TEST_ONLINE WHERE FRAUD_PATTERN = 'SUSPICIOUS_LEGIT'
UNION ALL
SELECT 
    'Normal-Looking Legit',
    COUNT(*),
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = FALSE), 2)
FROM FRAUD_ML_TEST_ONLINE WHERE FRAUD_PATTERN = 'NORMAL_LEGIT';

-- Sample of fraudulent transactions
SELECT 'Sample Fraudulent Transactions' AS info;
SELECT * FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = TRUE LIMIT 10;

-- Sample of legitimate transactions
SELECT 'Sample Legitimate Transactions' AS info;
SELECT * FROM FRAUD_ML_TEST_ONLINE WHERE IS_FRAUD = FALSE LIMIT 10;

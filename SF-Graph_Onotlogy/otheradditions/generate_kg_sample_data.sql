-- Script to generate 400K sample rows for KG_NODE and KG_EDGE tables for financial crime detection knowledge graph

-- Set context
USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;
USE WAREHOUSE GBU_A01A0E_FINCRIME_XS_WH;

-- =============================================================================
-- GENERATE 400K NODES (Various Entity Types)
-- =============================================================================

-- Clear existing data if needed (uncomment if you want to start fresh)
-- TRUNCATE TABLE KG_NODE;
-- TRUNCATE TABLE KG_EDGE;

-- Generate 400K Nodes with distribution across entity types:
-- 100K Customers, 80K Accounts, 150K Transactions, 30K Devices, 20K Merchants, 20K Addresses

INSERT INTO KG_NODE (NODE_ID, NODE_TYPE, NAME, PROPS, TS_INGESTED)
WITH RECURSIVE number_series AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM number_series WHERE n < 400000
),
node_generator AS (
    SELECT
        n,
        CASE 
            WHEN n <= 100000 THEN 'Customer'
            WHEN n <= 180000 THEN 'Account'
            WHEN n <= 330000 THEN 'Transaction'
            WHEN n <= 360000 THEN 'Device'
            WHEN n <= 380000 THEN 'Merchant'
            ELSE 'Address'
        END AS node_type,
        ABS(HASH(n)) AS random_seed
    FROM number_series
)
SELECT
    -- Generate unique NODE_ID based on type
    CASE node_type
        WHEN 'Customer' THEN 'CUST' || LPAD(n::VARCHAR, 8, '0')
        WHEN 'Account' THEN 'ACCT' || LPAD((n - 100000)::VARCHAR, 8, '0')
        WHEN 'Transaction' THEN 'TXN' || LPAD((n - 180000)::VARCHAR, 8, '0')
        WHEN 'Device' THEN 'DEV' || LPAD((n - 330000)::VARCHAR, 8, '0')
        WHEN 'Merchant' THEN 'MERCH' || LPAD((n - 360000)::VARCHAR, 8, '0')
        ELSE 'ADDR' || LPAD((n - 380000)::VARCHAR, 8, '0')
    END AS NODE_ID,
    
    node_type AS NODE_TYPE,
    
    -- Generate NAME based on type
    CASE node_type
        WHEN 'Customer' THEN 'Customer ' || n
        WHEN 'Account' THEN ARRAY_CONSTRUCT('Checking', 'Savings', 'Business', 'Investment', 'Credit')[MOD(random_seed, 5)]::VARCHAR || ' Account - ' || (n - 100000)
        WHEN 'Transaction' THEN 'Transaction ' || (n - 180000)
        WHEN 'Device' THEN 'Device ' || (n - 330000)
        WHEN 'Merchant' THEN 'Merchant ' || (n - 360000)
        ELSE 'Address ' || (n - 380000)
    END AS NAME,
    
    -- Generate realistic PROPS based on entity type
    CASE node_type
        WHEN 'Customer' THEN
            OBJECT_CONSTRUCT(
                'customer_id', 'CUST' || LPAD(n::VARCHAR, 8, '0'),
                'first_name', 'FirstName' || n,
                'last_name', 'LastName' || n,
                'email', 'customer' || n || '@example.com',
                'phone', '+1' || LPAD(MOD(random_seed, 9999999999)::VARCHAR, 10, '0'),
                'date_of_birth', DATEADD(year, -1 * (18 + MOD(ABS(HASH(n * 1000 + 1)), 63)), CURRENT_DATE()),
                'kyc_status', ARRAY_CONSTRUCT('verified', 'pending', 'unverified', 'flagged')[MOD(random_seed, 4)]::VARCHAR,
                'risk_score', ROUND(MOD(ABS(HASH(n * 1000 + 2)), 101), 2),
                'registration_date', DATEADD(day, -1 * (1 + MOD(ABS(HASH(n * 1000 + 3)), 3650)), CURRENT_DATE())
            )
        
        WHEN 'Account' THEN
            OBJECT_CONSTRUCT(
                'account_number', LPAD((n - 100000)::VARCHAR, 12, '0'),
                'account_type', ARRAY_CONSTRUCT('checking', 'savings', 'business', 'investment', 'credit')[MOD(random_seed, 5)]::VARCHAR,
                'balance', ROUND(MOD(ABS(HASH(n * 1000 + 4)), 500001), 2),
                'currency', ARRAY_CONSTRUCT('USD', 'EUR', 'GBP', 'JPY')[MOD(random_seed, 4)]::VARCHAR,
                'opened_date', DATEADD(day, -1 * (1 + MOD(ABS(HASH(n * 1000 + 5)), 3650)), CURRENT_DATE()),
                'status', ARRAY_CONSTRUCT('active', 'frozen', 'dormant', 'closed')[MOD(random_seed * 7, 4)]::VARCHAR,
                'branch_code', 'BR' || LPAD(MOD(random_seed, 500)::VARCHAR, 4, '0')
            )
        
        WHEN 'Transaction' THEN
            OBJECT_CONSTRUCT(
                'transaction_id', 'TXN' || LPAD((n - 180000)::VARCHAR, 8, '0'),
                'amount', ROUND((10 + MOD(ABS(HASH(n * 1000 + 6)), 49991)), 2),
                'currency', ARRAY_CONSTRUCT('USD', 'EUR', 'GBP', 'JPY')[MOD(random_seed, 4)]::VARCHAR,
                'transaction_type', ARRAY_CONSTRUCT('transfer', 'withdrawal', 'deposit', 'payment', 'purchase')[MOD(random_seed, 5)]::VARCHAR,
                'timestamp', DATEADD(minute, -1 * (1 + MOD(ABS(HASH(n * 1000 + 7)), 525600)), CURRENT_TIMESTAMP()),
                'status', ARRAY_CONSTRUCT('completed', 'pending', 'failed', 'flagged')[MOD(random_seed * 3, 4)]::VARCHAR,
                'channel', ARRAY_CONSTRUCT('online', 'mobile', 'atm', 'branch', 'phone')[MOD(random_seed, 5)]::VARCHAR,
                'anomaly_score', ROUND(MOD(ABS(HASH(n * 1000 + 8)), 101), 2)
            )
        
        WHEN 'Device' THEN
            OBJECT_CONSTRUCT(
                'device_id', 'DEV' || LPAD((n - 330000)::VARCHAR, 8, '0'),
                'device_type', ARRAY_CONSTRUCT('mobile', 'desktop', 'tablet', 'atm')[MOD(random_seed, 4)]::VARCHAR,
                'os', ARRAY_CONSTRUCT('iOS', 'Android', 'Windows', 'MacOS', 'Linux')[MOD(random_seed, 5)]::VARCHAR,
                'ip_address', 
                    MOD(random_seed, 256) || '.' || 
                    MOD(random_seed / 256, 256) || '.' || 
                    MOD(random_seed / 65536, 256) || '.' || 
                    MOD(random_seed / 16777216, 256),
                'first_seen', DATEADD(day, -1 * (1 + MOD(ABS(HASH(n * 1000 + 9)), 1825)), CURRENT_DATE()),
                'last_seen', DATEADD(day, -1 * (1 + MOD(ABS(HASH(n * 1000 + 10)), 30)), CURRENT_DATE()),
                'is_trusted', MOD(random_seed, 10) < 8
            )
        
        WHEN 'Merchant' THEN
            OBJECT_CONSTRUCT(
                'merchant_id', 'MERCH' || LPAD((n - 360000)::VARCHAR, 8, '0'),
                'merchant_name', 'Merchant Business ' || (n - 360000),
                'category', ARRAY_CONSTRUCT('retail', 'restaurant', 'online', 'travel', 'entertainment', 'utilities', 'healthcare')[MOD(random_seed, 7)]::VARCHAR,
                'mcc_code', LPAD(MOD(random_seed, 9999)::VARCHAR, 4, '0'),
                'country', ARRAY_CONSTRUCT('US', 'UK', 'DE', 'FR', 'JP', 'CN', 'AU')[MOD(random_seed, 7)]::VARCHAR,
                'risk_rating', ARRAY_CONSTRUCT('low', 'medium', 'high')[MOD(random_seed, 3)]::VARCHAR,
                'registration_date', DATEADD(day, -1 * (1 + MOD(ABS(HASH(n * 1000 + 11)), 3650)), CURRENT_DATE())
            )
        
        ELSE -- Address
            OBJECT_CONSTRUCT(
                'address_id', 'ADDR' || LPAD((n - 380000)::VARCHAR, 8, '0'),
                'street', MOD(random_seed, 9999) || ' Main Street',
                'city', ARRAY_CONSTRUCT('New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'London', 'Paris')[MOD(random_seed, 7)]::VARCHAR,
                'state', ARRAY_CONSTRUCT('NY', 'CA', 'IL', 'TX', 'AZ', 'FL', 'WA')[MOD(random_seed, 7)]::VARCHAR,
                'country', ARRAY_CONSTRUCT('US', 'UK', 'DE', 'FR', 'JP', 'CN', 'AU')[MOD(random_seed, 7)]::VARCHAR,
                'postal_code', LPAD(MOD(random_seed, 99999)::VARCHAR, 5, '0'),
                'is_verified', MOD(random_seed, 10) < 7
            )
    END AS PROPS,
    
    DATEADD(minute, -1 * (1 + MOD(ABS(HASH(n * 1000 + 12)), 525600)), CURRENT_TIMESTAMP()) AS TS_INGESTED
FROM node_generator;

-- =============================================================================
-- GENERATE 400K EDGES (Various Relationship Types)
-- =============================================================================

INSERT INTO KG_EDGE (EDGE_ID, SRC_ID, DST_ID, EDGE_TYPE, WEIGHT, PROPS, EFFECTIVE_START, EFFECTIVE_END, TS_INGESTED)
WITH RECURSIVE edge_series AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM edge_series WHERE n < 400000
),
edge_generator AS (
    SELECT
        n,
        (1 + MOD(ABS(HASH(n * 1000 + 100000)), 1000000)) AS random_seed,
        (1 + MOD(ABS(HASH(n * 1000 + 200000)), 100000)) AS cust_id,
        (1 + MOD(ABS(HASH(n * 1000 + 300000)), 80000)) AS acct_id,
        (1 + MOD(ABS(HASH(n * 1000 + 400000)), 150000)) AS txn_id,
        (1 + MOD(ABS(HASH(n * 1000 + 500000)), 30000)) AS dev_id,
        (1 + MOD(ABS(HASH(n * 1000 + 600000)), 20000)) AS merch_id,
        (1 + MOD(ABS(HASH(n * 1000 + 700000)), 20000)) AS addr_id,
        (1 + MOD(ABS(HASH(n * 1000 + 800000)), 1095)) AS days_back
    FROM edge_series
)
SELECT
    'EDGE' || LPAD(n::VARCHAR, 8, '0') AS EDGE_ID,
    
    -- Generate SRC_ID and DST_ID based on relationship type patterns
    CASE 
        -- Customer OWNS Account (40K edges)
        WHEN n <= 40000 THEN 'CUST' || LPAD(cust_id::VARCHAR, 8, '0')
        -- Transaction FROM_ACCOUNT (80K edges)
        WHEN n <= 120000 THEN 'TXN' || LPAD(txn_id::VARCHAR, 8, '0')
        -- Transaction TO_ACCOUNT (80K edges)
        WHEN n <= 200000 THEN 'TXN' || LPAD(txn_id::VARCHAR, 8, '0')
        -- Customer USES Device (50K edges)
        WHEN n <= 250000 THEN 'CUST' || LPAD(cust_id::VARCHAR, 8, '0')
        -- Transaction USED_DEVICE (50K edges)
        WHEN n <= 300000 THEN 'TXN' || LPAD(txn_id::VARCHAR, 8, '0')
        -- Transaction AT_MERCHANT (40K edges)
        WHEN n <= 340000 THEN 'TXN' || LPAD(txn_id::VARCHAR, 8, '0')
        -- Customer HAS_ADDRESS (30K edges)
        WHEN n <= 370000 THEN 'CUST' || LPAD(cust_id::VARCHAR, 8, '0')
        -- Customer RELATED_TO Customer (20K edges - family, business relationships)
        WHEN n <= 390000 THEN 'CUST' || LPAD(cust_id::VARCHAR, 8, '0')
        -- Account LINKED_TO Account (10K edges - joint accounts, transfers)
        ELSE 'ACCT' || LPAD(acct_id::VARCHAR, 8, '0')
    END AS SRC_ID,
    
    CASE 
        -- Customer OWNS Account
        WHEN n <= 40000 THEN 'ACCT' || LPAD(acct_id::VARCHAR, 8, '0')
        -- Transaction FROM_ACCOUNT
        WHEN n <= 120000 THEN 'ACCT' || LPAD(acct_id::VARCHAR, 8, '0')
        -- Transaction TO_ACCOUNT
        WHEN n <= 200000 THEN 'ACCT' || LPAD(((1 + MOD(ABS(HASH(n * 1000 + 900000)), 80000)))::VARCHAR, 8, '0')
        -- Customer USES Device
        WHEN n <= 250000 THEN 'DEV' || LPAD(dev_id::VARCHAR, 8, '0')
        -- Transaction USED_DEVICE
        WHEN n <= 300000 THEN 'DEV' || LPAD(dev_id::VARCHAR, 8, '0')
        -- Transaction AT_MERCHANT
        WHEN n <= 340000 THEN 'MERCH' || LPAD(merch_id::VARCHAR, 8, '0')
        -- Customer HAS_ADDRESS
        WHEN n <= 370000 THEN 'ADDR' || LPAD(addr_id::VARCHAR, 8, '0')
        -- Customer RELATED_TO Customer
        WHEN n <= 390000 THEN 'CUST' || LPAD(((1 + MOD(ABS(HASH(n * 1000 + 950000)), 100000)))::VARCHAR, 8, '0')
        -- Account LINKED_TO Account
        ELSE 'ACCT' || LPAD(((1 + MOD(ABS(HASH(n * 1000 + 980000)), 80000)))::VARCHAR, 8, '0')
    END AS DST_ID,
    
    -- Assign EDGE_TYPE based on ranges
    CASE 
        WHEN n <= 40000 THEN 'OWNS'
        WHEN n <= 120000 THEN 'FROM_ACCOUNT'
        WHEN n <= 200000 THEN 'TO_ACCOUNT'
        WHEN n <= 250000 THEN 'USES_DEVICE'
        WHEN n <= 300000 THEN 'USED_DEVICE'
        WHEN n <= 340000 THEN 'AT_MERCHANT'
        WHEN n <= 370000 THEN 'HAS_ADDRESS'
        WHEN n <= 390000 THEN ARRAY_CONSTRUCT('RELATED_TO', 'CO_OWNER', 'AUTHORIZED_USER', 'BENEFICIARY')[MOD(random_seed, 4)]::VARCHAR
        ELSE 'LINKED_TO'
    END AS EDGE_TYPE,
    
    -- Generate weight based on relationship strength
    CASE 
        WHEN n <= 40000 THEN ROUND((0.5 + (MOD(ABS(HASH(n * 1000 + 1100000)), 51) / 100.0)), 2)
        WHEN n <= 200000 THEN 1.0
        WHEN n <= 300000 THEN ROUND((0.3 + (MOD(ABS(HASH(n * 1000 + 1200000)), 71) / 100.0)), 2)
        WHEN n <= 340000 THEN 1.0
        ELSE ROUND((0.5 + (MOD(ABS(HASH(n * 1000 + 1300000)), 51) / 100.0)), 2)
    END AS WEIGHT,
    
    -- Generate PROPS with relationship-specific metadata
    CASE 
        WHEN n <= 40000 THEN
            OBJECT_CONSTRUCT(
                'ownership_type', ARRAY_CONSTRUCT('primary', 'joint', 'secondary')[MOD(random_seed, 3)]::VARCHAR,
                'start_date', DATEADD(day, -1 * days_back, CURRENT_DATE())
            )
        
        WHEN n <= 200000 THEN
            OBJECT_CONSTRUCT(
                'role', CASE WHEN n <= 120000 THEN 'source' ELSE 'destination' END,
                'amount', ROUND((10 + MOD(ABS(HASH(n * 1000 + 1400000)), 49991)), 2),
                'currency', ARRAY_CONSTRUCT('USD', 'EUR', 'GBP')[MOD(random_seed, 3)]::VARCHAR
            )
        
        WHEN n <= 300000 THEN
            OBJECT_CONSTRUCT(
                'session_id', 'SES' || LPAD(MOD(random_seed, 999999)::VARCHAR, 6, '0'),
                'location', ARRAY_CONSTRUCT('home', 'work', 'travel', 'public')[MOD(random_seed, 4)]::VARCHAR,
                'is_suspicious', MOD(random_seed, 20) = 0
            )
        
        WHEN n <= 340000 THEN
            OBJECT_CONSTRUCT(
                'transaction_amount', ROUND((10 + MOD(ABS(HASH(n * 1000 + 1500000)), 9991)), 2),
                'currency', 'USD',
                'merchant_category', ARRAY_CONSTRUCT('retail', 'restaurant', 'online', 'travel')[MOD(random_seed, 4)]::VARCHAR
            )
        
        WHEN n <= 370000 THEN
            OBJECT_CONSTRUCT(
                'address_type', ARRAY_CONSTRUCT('residential', 'work', 'mailing', 'billing')[MOD(random_seed, 4)]::VARCHAR,
                'is_primary', MOD(random_seed, 4) = 0
            )
        
        WHEN n <= 390000 THEN
            OBJECT_CONSTRUCT(
                'relationship_type', ARRAY_CONSTRUCT('family', 'business', 'spouse', 'parent', 'sibling')[MOD(random_seed, 5)]::VARCHAR,
                'confidence', ROUND((0.5 + (MOD(ABS(HASH(n * 1000 + 1600000)), 51) / 100.0)), 2)
            )
        
        ELSE
            OBJECT_CONSTRUCT(
                'link_type', ARRAY_CONSTRUCT('transfer', 'joint', 'related')[MOD(random_seed, 3)]::VARCHAR,
                'frequency', (1 + MOD(ABS(HASH(n * 1000 + 1700000)), 100))
            )
    END AS PROPS,
    
    -- EFFECTIVE_START (time-bounded relationships)
    DATEADD(day, -1 * days_back, CURRENT_DATE()) AS EFFECTIVE_START,
    
    -- EFFECTIVE_END (some relationships are ongoing, some expired)
    CASE 
        -- 70% ongoing relationships (null end date)
        WHEN MOD(random_seed, 10) < 7 THEN NULL
        -- 30% expired relationships
        ELSE DATEADD(day, -1 * (1 + MOD(ABS(HASH(n * 1000 + 1800000)), days_back)), CURRENT_DATE())
    END AS EFFECTIVE_END,
    
    DATEADD(minute, -1 * (1 + MOD(ABS(HASH(n * 1000 + 1900000)), 525600)), CURRENT_TIMESTAMP()) AS TS_INGESTED
FROM edge_generator;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Check node counts by type
SELECT NODE_TYPE, COUNT(*) AS node_count
FROM KG_NODE
GROUP BY NODE_TYPE
ORDER BY NODE_TYPE;

-- Check edge counts by type
SELECT EDGE_TYPE, COUNT(*) AS edge_count
FROM KG_EDGE
GROUP BY EDGE_TYPE
ORDER BY EDGE_TYPE;

-- Check total counts
SELECT 
    (SELECT COUNT(*) FROM KG_NODE) AS total_nodes,
    (SELECT COUNT(*) FROM KG_EDGE) AS total_edges;

-- Sample active relationships (EFFECTIVE_END is null or in future)
SELECT EDGE_TYPE, COUNT(*) AS active_relationships
FROM KG_EDGE
WHERE EFFECTIVE_END IS NULL OR EFFECTIVE_END >= CURRENT_DATE()
GROUP BY EDGE_TYPE
ORDER BY EDGE_TYPE;

-- Sample data preview
SELECT * FROM KG_NODE LIMIT 10;
SELECT * FROM KG_EDGE LIMIT 10;

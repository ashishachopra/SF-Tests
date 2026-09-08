-- ============================================================================
-- COMPLETE ONTOLOGY UPDATE SCRIPT
-- Part 1: Fix existing ONT_OBJECT_SOURCE and ONT_LINK_SOURCE entries
-- Part 2: Add missing classes, properties, and relationships
-- ============================================================================
-- Database: A01A0E_GBU_FINCRIME_POC
-- Schema: GRAPH_ONTOLOGY
-- ============================================================================

USE DATABASE A01A0E_GBU_FINCRIME_POC;
USE SCHEMA GRAPH_ONTOLOGY;

-- ============================================================================
-- PART 1: UPDATE EXISTING ENTRIES
-- ============================================================================

-- ============================================================================
-- 1.1 UPDATE ONT_OBJECT_SOURCE - Fix NODE_TYPE filters
-- ============================================================================

-- Update Customer mapping: PLAYER → Customer
UPDATE ONT_OBJECT_SOURCE
SET FILTER_SQL = 'NODE_TYPE = ''Customer''',
    MAPPING = PARSE_JSON('{
      "NODE_ID": "id",
      "NAME": "name",
      "PROPS:NAME": "name",
      "PROPS:ADDRESS": "address",
      "PROPS:EMAIL": "email",
      "PROPS:PHONENUMBER": "phonenumber",
      "PROPS:BIRTHDATE": "birthdate",
      "PROPS:NATIONALITY": "nationality",
      "PROPS:CUSTOMERTYPE": "customertype"
    }')
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY'
  AND OBJ_TYPE = 'Customer';

-- Update Account mapping: COACH → Account
UPDATE ONT_OBJECT_SOURCE
SET FILTER_SQL = 'NODE_TYPE = ''Account''',
    MAPPING = PARSE_JSON('{
      "NODE_ID": "id",
      "NAME": "name",
      "PROPS:NAME": "name",
      "PROPS:ACCOUNTTYPE": "accounttype",
      "PROPS:ACCOUNTBALANCE": "accountbalance",
      "PROPS:PRIMARYCUSTOMER": "primarycustomer",
      "PROPS:OPENDATE": "opendate",
      "PROPS:CLOSEDDATE": "closeddate",
      "PROPS:RELATIONSHIPMANAGER": "relationshipmanager"
    }')
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY'
  AND OBJ_TYPE = 'Account';

-- Update Device mapping: CLUB → Device
UPDATE ONT_OBJECT_SOURCE
SET FILTER_SQL = 'NODE_TYPE = ''Device''',
    MAPPING = PARSE_JSON('{
      "NODE_ID": "id",
      "NAME": "name",
      "PROPS:NAME": "name",
      "PROPS:DEVICETYPE": "devicetype",
      "PROPS:IMEINUMBER": "imeinumber",
      "PROPS:PHONENUMBER": "phonenumber",
      "PROPS:VERSION": "version",
      "PROPS:PRIMARYCUSTOMER": "primarycustomer"
    }')
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY'
  AND OBJ_TYPE = 'Device';

-- Delete Transaction mapping (MATCH reference)
DELETE FROM ONT_OBJECT_SOURCE
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY'
  AND OBJ_TYPE = 'Transaction'
  AND FILTER_SQL = 'NODE_TYPE = ''MATCH''';

-- ============================================================================
-- 1.2 CLEAN UP ONT_LINK_SOURCE - Remove incorrect mappings
-- ============================================================================

-- Delete incorrect link source mappings that don't match actual KG_EDGE data
DELETE FROM ONT_LINK_SOURCE
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY'
  AND LINK_TYPE IN ('CUST_OWNS_PRODUCT', 'CUSTOMER_TRANSACTIONS', 'PRODUCT_TRANSACTIONS');


-- ============================================================================
-- PART 2: ADD MISSING ONTOLOGY DEFINITIONS
-- ============================================================================

-- ============================================================================
-- 2.1 INSERT MISSING CLASSES INTO ONT_CLASS
-- ============================================================================

-- Add Merchant class
INSERT INTO ONT_CLASS 
(ONTOLOGY_NAME, CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT, DESCRIPTION, TYPE_CLASS, STATUS, TS_CREATED)
VALUES 
('GRAPH_ONTOLOGY', 'Merchant', 'Thing', FALSE, 'Merchant entity representing businesses that accept transactions', 'OPERATIONAL', 'ACTIVE', CURRENT_TIMESTAMP());

-- Add Address class
INSERT INTO ONT_CLASS 
(ONTOLOGY_NAME, CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT, DESCRIPTION, TYPE_CLASS, STATUS, TS_CREATED)
VALUES 
('GRAPH_ONTOLOGY', 'Address', 'Thing', FALSE, 'Physical address entity', 'OPERATIONAL', 'ACTIVE', CURRENT_TIMESTAMP());


-- ============================================================================
-- 2.2 INSERT PROPERTIES FOR NEW CLASSES INTO ONT_PROPERTY
-- ============================================================================

-- Properties for Merchant class
INSERT INTO ONT_PROPERTY 
(CLASS_NAME, PROP_NAME, DATA_TYPE, IS_REQUIRED, IS_INDEXED, DESCRIPTION)
VALUES 
('Merchant', 'merchant_id', 'STRING', TRUE, TRUE, 'Unique merchant identifier'),
('Merchant', 'merchant_name', 'STRING', TRUE, TRUE, 'Name of the merchant'),
('Merchant', 'name', 'STRING', TRUE, TRUE, 'Display name of the merchant'),
('Merchant', 'category', 'STRING', TRUE, TRUE, 'Merchant business category'),
('Merchant', 'country', 'STRING', TRUE, TRUE, 'Country where merchant operates'),
('Merchant', 'mcc_code', 'STRING', TRUE, TRUE, 'Merchant Category Code'),
('Merchant', 'risk_rating', 'STRING', FALSE, TRUE, 'Risk rating of merchant (low/medium/high)'),
('Merchant', 'registration_date', 'DATE', FALSE, FALSE, 'Date when merchant was registered');

-- Properties for Address class
INSERT INTO ONT_PROPERTY 
(CLASS_NAME, PROP_NAME, DATA_TYPE, IS_REQUIRED, IS_INDEXED, DESCRIPTION)
VALUES 
('Address', 'address_id', 'STRING', TRUE, TRUE, 'Unique address identifier'),
('Address', 'street', 'STRING', TRUE, FALSE, 'Street address'),
('Address', 'city', 'STRING', TRUE, TRUE, 'City name'),
('Address', 'state', 'STRING', TRUE, TRUE, 'State or province'),
('Address', 'postal_code', 'STRING', FALSE, TRUE, 'Postal or ZIP code'),
('Address', 'country', 'STRING', TRUE, TRUE, 'Country code or name'),
('Address', 'is_verified', 'BOOLEAN', FALSE, FALSE, 'Whether address has been verified');


-- ============================================================================
-- 2.3 INSERT MISSING RELATIONSHIPS INTO ONT_RELATION_DEF
-- ============================================================================

-- Transaction -> Merchant (AT_MERCHANT)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'AT_MERCHANT', 'Transaction', 'Merchant', 'N:1', FALSE, 'HAS_TRANSACTIONS', 'Transaction occurred at merchant', 'ACTIVE', 'directed');

-- Customer -> Address (HAS_ADDRESS)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'HAS_ADDRESS', 'Customer', 'Address', 'N:1', FALSE, 'ADDRESS_OF', 'Customer has address', 'ACTIVE', 'directed');

-- Customer -> Customer (REFERRED)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'REFERRED', 'Customer', 'Customer', 'N:N', FALSE, 'REFERRED_BY', 'Customer referred another customer', 'ACTIVE', 'directed');

-- Customer -> Customer (CO_OWNER)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'CO_OWNER', 'Customer', 'Customer', 'N:N', FALSE, 'CO_OWNER', 'Customer is co-owner with another customer', 'ACTIVE', 'undirected');

-- Customer -> Customer (BENEFICIARY)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'BENEFICIARY', 'Customer', 'Customer', 'N:N', FALSE, 'BENEFACTOR', 'Customer is beneficiary of another customer', 'ACTIVE', 'directed');

-- Customer -> Customer (AUTHORIZED_USER)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'AUTHORIZED_USER', 'Customer', 'Customer', 'N:N', FALSE, 'AUTHORIZED_BY', 'Customer is authorized user for another customer', 'ACTIVE', 'directed');

-- Customer -> Customer (RELATED_TO)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'RELATED_TO', 'Customer', 'Customer', 'N:N', FALSE, 'RELATED_TO', 'Customer is related to another customer', 'ACTIVE', 'undirected');

-- Customer -> Device (USES_DEVICE)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'USES_DEVICE', 'Customer', 'Device', 'N:N', FALSE, 'USED_BY', 'Customer uses device', 'ACTIVE', 'directed');

-- Device -> Customer (USED_BY)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'USED_BY', 'Device', 'Customer', 'N:N', FALSE, 'USES', 'Device used by customer', 'ACTIVE', 'directed');

-- Customer -> Account (OWNS)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'OWNS', 'Customer', 'Account', 'N:N', FALSE, 'OWNED_BY', 'Customer owns account', 'ACTIVE', 'directed');

-- Transaction -> Account (FROM_ACCOUNT)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'FROM_ACCOUNT', 'Transaction', 'Account', 'N:1', FALSE, 'SOURCE_OF_TXN', 'Transaction originates from account', 'ACTIVE', 'directed');

-- Transaction -> Account (TO_ACCOUNT)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'TO_ACCOUNT', 'Transaction', 'Account', 'N:1', FALSE, 'DEST_OF_TXN', 'Transaction goes to account', 'ACTIVE', 'directed');

-- Transaction -> Device (INITIATED_FROM)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'INITIATED_FROM', 'Transaction', 'Device', 'N:1', FALSE, 'INITIATED_TXN', 'Transaction initiated from device', 'ACTIVE', 'directed');

-- Transaction -> Device (USED_DEVICE)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'USED_DEVICE', 'Transaction', 'Device', 'N:1', FALSE, 'DEVICE_FOR_TXN', 'Transaction used device', 'ACTIVE', 'directed');

-- Account -> Transaction (TRANSACTED)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'TRANSACTED', 'Account', 'Transaction', '1:N', FALSE, 'ON_ACCOUNT', 'Account has transaction', 'ACTIVE', 'directed');

-- Account -> Account (LINKED_TO)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'LINKED_TO', 'Account', 'Account', 'N:N', FALSE, 'LINKED_TO', 'Account is linked to another account', 'ACTIVE', 'undirected');

-- Account -> Account (TRANSFERRED_TO)
INSERT INTO ONT_RELATION_DEF 
(ONTOLOGY_NAME, REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, IS_HIERARCHICAL, INVERSE_REL_NAME, DESCRIPTION, STATUS, RENDER_HINT)
VALUES 
('GRAPH_ONTOLOGY', 'TRANSFERRED_TO', 'Account', 'Account', 'N:N', FALSE, 'RECEIVED_FROM', 'Funds transferred from account to account', 'ACTIVE', 'directed');


-- ============================================================================
-- 2.4 INSERT OBJECT SOURCES FOR NEW CLASSES INTO ONT_OBJECT_SOURCE
-- ============================================================================

-- Add Merchant object source
INSERT INTO ONT_OBJECT_SOURCE 
(ONTOLOGY_NAME, OBJ_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'Merchant', 
  'KG_NODE', 
  'NODE_TYPE = ''Merchant''',
  PARSE_JSON('{
    "NODE_ID": "merchant_id",
    "NAME": "name",
    "PROPS:MERCHANT_ID": "merchant_id",
    "PROPS:MERCHANT_NAME": "merchant_name",
    "PROPS:CATEGORY": "category",
    "PROPS:COUNTRY": "country",
    "PROPS:MCC_CODE": "mcc_code",
    "PROPS:RISK_RATING": "risk_rating",
    "PROPS:REGISTRATION_DATE": "registration_date"
  }');

-- Add Address object source
INSERT INTO ONT_OBJECT_SOURCE 
(ONTOLOGY_NAME, OBJ_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'Address', 
  'KG_NODE', 
  'NODE_TYPE = ''Address''',
  PARSE_JSON('{
    "NODE_ID": "address_id",
    "NAME": "name",
    "PROPS:ADDRESS_ID": "address_id",
    "PROPS:STREET": "street",
    "PROPS:CITY": "city",
    "PROPS:STATE": "state",
    "PROPS:POSTAL_CODE": "postal_code",
    "PROPS:COUNTRY": "country",
    "PROPS:IS_VERIFIED": "is_verified"
  }');


-- ============================================================================
-- 2.5 INSERT LINK SOURCES FOR NEW RELATIONSHIPS INTO ONT_LINK_SOURCE
-- ============================================================================

-- AT_MERCHANT link (Transaction -> Merchant)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'AT_MERCHANT', 
  'KG_EDGE', 
  'EDGE_TYPE = ''AT_MERCHANT''',
  PARSE_JSON('{
    "SRC_ID": "transaction_id",
    "DST_ID": "merchant_id",
    "EFFECTIVE_START": "effective_start",
    "EFFECTIVE_END": "effective_end",
    "PROPS:TRANSACTION_AMOUNT": "transaction_amount",
    "PROPS:CURRENCY": "currency",
    "PROPS:MERCHANT_CATEGORY": "merchant_category"
  }');

-- HAS_ADDRESS link (Customer -> Address)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'HAS_ADDRESS', 
  'KG_EDGE', 
  'EDGE_TYPE = ''HAS_ADDRESS''',
 PARSE_JSON('{
   "SRC_ID": "customer_id",
   "DST_ID": "address_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- REFERRED link (Customer -> Customer)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'REFERRED', 
  'KG_EDGE', 
  'EDGE_TYPE = ''REFERRED''',
 PARSE_JSON('{
   "SRC_ID": "referrer_customer_id",
   "DST_ID": "referred_customer_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- CO_OWNER link (Customer -> Customer)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'CO_OWNER', 
  'KG_EDGE', 
  'EDGE_TYPE = ''CO_OWNER''',
 PARSE_JSON('{
   "SRC_ID": "customer_id_1",
   "DST_ID": "customer_id_2",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- BENEFICIARY link (Customer -> Customer)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'BENEFICIARY', 
  'KG_EDGE', 
  'EDGE_TYPE = ''BENEFICIARY''',
 PARSE_JSON('{
   "SRC_ID": "beneficiary_customer_id",
   "DST_ID": "benefactor_customer_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- AUTHORIZED_USER link (Customer -> Customer)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'AUTHORIZED_USER', 
  'KG_EDGE', 
  'EDGE_TYPE = ''AUTHORIZED_USER''',
 PARSE_JSON('{
   "SRC_ID": "authorized_customer_id",
   "DST_ID": "authorizing_customer_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- RELATED_TO link (Customer -> Customer)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'RELATED_TO', 
  'KG_EDGE', 
  'EDGE_TYPE = ''RELATED_TO''',
 PARSE_JSON('{
   "SRC_ID": "customer_id_1",
   "DST_ID": "customer_id_2",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- USES_DEVICE link (Customer -> Device)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'USES_DEVICE', 
  'KG_EDGE', 
  'EDGE_TYPE = ''USES_DEVICE''',
 PARSE_JSON('{
   "SRC_ID": "customer_id",
   "DST_ID": "device_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- USED_BY link (Device -> Customer)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'USED_BY', 
  'KG_EDGE', 
  'EDGE_TYPE = ''USED_BY''',
 PARSE_JSON('{
   "SRC_ID": "device_id",
   "DST_ID": "customer_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- OWNS link (Customer -> Account)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'OWNS', 
  'KG_EDGE', 
  'EDGE_TYPE = ''OWNS''',
 PARSE_JSON('{
   "SRC_ID": "customer_id",
   "DST_ID": "account_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- FROM_ACCOUNT link (Transaction -> Account)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'FROM_ACCOUNT', 
  'KG_EDGE', 
  'EDGE_TYPE = ''FROM_ACCOUNT''',
 PARSE_JSON('{
   "SRC_ID": "transaction_id",
   "DST_ID": "account_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- TO_ACCOUNT link (Transaction -> Account)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'TO_ACCOUNT', 
  'KG_EDGE', 
  'EDGE_TYPE = ''TO_ACCOUNT''',
 PARSE_JSON('{
   "SRC_ID": "transaction_id",
   "DST_ID": "account_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- INITIATED_FROM link (Transaction -> Device)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'INITIATED_FROM', 
  'KG_EDGE', 
  'EDGE_TYPE = ''INITIATED_FROM''',
 PARSE_JSON('{
   "SRC_ID": "transaction_id",
   "DST_ID": "device_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- USED_DEVICE link (Transaction -> Device)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'USED_DEVICE', 
  'KG_EDGE', 
  'EDGE_TYPE = ''USED_DEVICE''',
 PARSE_JSON('{
   "SRC_ID": "transaction_id",
   "DST_ID": "device_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- TRANSACTED link (Account -> Transaction)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'TRANSACTED', 
  'KG_EDGE', 
  'EDGE_TYPE = ''TRANSACTED''',
 PARSE_JSON('{
   "SRC_ID": "account_id",
   "DST_ID": "transaction_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- LINKED_TO link (Account -> Account)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'LINKED_TO', 
  'KG_EDGE', 
  'EDGE_TYPE = ''LINKED_TO''',
 PARSE_JSON('{
   "SRC_ID": "account_id_1",
   "DST_ID": "account_id_2",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');

-- TRANSFERRED_TO link (Account -> Account)
INSERT INTO ONT_LINK_SOURCE 
(ONTOLOGY_NAME, LINK_TYPE, SOURCE_TABLE, FILTER_SQL, MAPPING)
SELECT 
  'GRAPH_ONTOLOGY', 
  'TRANSFERRED_TO', 
  'KG_EDGE', 
  'EDGE_TYPE = ''TRANSFERRED_TO''',
 PARSE_JSON('{
   "SRC_ID": "from_account_id",
   "DST_ID": "to_account_id",
   "EFFECTIVE_START": "effective_start",
   "EFFECTIVE_END": "effective_end"
 }');


-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Count of classes
SELECT 'Classes' as OBJECT_TYPE, COUNT(*) as COUNT
FROM ONT_CLASS
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY';

-- Count of properties
SELECT 'Properties' as OBJECT_TYPE, COUNT(*) as COUNT
FROM ONT_PROPERTY;

-- Count of relationships
SELECT 'Relationships' as OBJECT_TYPE, COUNT(*) as COUNT
FROM ONT_RELATION_DEF
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY';

-- Count of object sources
SELECT 'Object Sources' as OBJECT_TYPE, COUNT(*) as COUNT
FROM ONT_OBJECT_SOURCE
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY';

-- Count of link sources
SELECT 'Link Sources' as OBJECT_TYPE, COUNT(*) as COUNT
FROM ONT_LINK_SOURCE
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY';

-- List all classes
SELECT CLASS_NAME, PARENT_CLASS_NAME, IS_ABSTRACT, DESCRIPTION
FROM ONT_CLASS
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY'
ORDER BY CLASS_NAME;

-- List all relationships
SELECT REL_NAME, DOMAIN_CLASS, RANGE_CLASS, CARDINALITY, DESCRIPTION
FROM ONT_RELATION_DEF
WHERE ONTOLOGY_NAME = 'GRAPH_ONTOLOGY'
ORDER BY REL_NAME;

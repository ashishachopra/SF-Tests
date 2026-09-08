-- ============================================================================
-- 04_setup_udfs.sql
-- Creates custom AI UDFs (tools for agents)
-- Run BEFORE agents since agents use these as tools
-- ============================================================================

USE DATABASE CUSTOMER_INTELLIGENCE_DB;
USE SCHEMA PUBLIC;

-- ============================================================================
-- 1. AI_ANALYZE_CUSTOMER_SEGMENT
-- Used by: RESEARCH_AGENT (CUSTOMER_SEGMENT_INTELLIGENCE tool)
-- Purpose: Strategic customer segment analysis with AI insights
-- ============================================================================

CREATE OR REPLACE FUNCTION CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_SEGMENT("CUSTOMER_IDS_STRING" VARCHAR, "SEGMENT_NAME" VARCHAR DEFAULT 'high_value_customers')
RETURNS VARIANT
LANGUAGE SQL
AS '
WITH parsed_customer_ids AS (
  -- Parse comma-separated string into individual customer IDs
  SELECT 
    TRIM(VALUE) as customer_id
  FROM TABLE(SPLIT_TO_TABLE(customer_ids_string, '',''))
),
target_customers AS (
  SELECT 
    c.customer_id,
    c.plan_type,
    c.monthly_revenue,
    c.company_size,
    c.industry,
    c.status,
    DATEDIFF(''day'', c.signup_date, CURRENT_DATE()) as customer_age_days
  FROM customers c
  INNER JOIN parsed_customer_ids pci ON c.customer_id = pci.customer_id
),
segment_usage AS (
  SELECT 
    COUNT(DISTINCT u.customer_id) as active_users,
    COUNT(*) as total_events,
    ROUND(AVG(u.session_duration_minutes), 2) as avg_session_duration,
    SUM(u.actions_count) as total_actions
  FROM usage_events u
  INNER JOIN parsed_customer_ids pci ON u.customer_id = pci.customer_id
  WHERE u.event_date >= CURRENT_DATE() - 365 - 90  -- Handle data offset
),
segment_support AS (
  SELECT 
    COUNT(*) as total_tickets,
    ROUND(AVG(satisfaction_score), 2) as avg_satisfaction,
    COUNT(CASE WHEN priority IN (''high'', ''critical'') THEN 1 END) as high_priority_tickets
  FROM support_tickets s
  INNER JOIN parsed_customer_ids pci ON s.customer_id = pci.customer_id
  WHERE s.created_date >= CURRENT_DATE() - 365 - 90  -- Handle data offset
),
segment_summary AS (
  SELECT 
    tc.customer_count,
    tc.total_mrr,
    tc.avg_revenue,
    tc.plan_mix,
    su.active_users,
    su.total_events,
    su.avg_session_duration,
    ss.total_tickets,
    ss.avg_satisfaction,
    -- AI analysis with proper input validation
    CASE 
      WHEN tc.customer_count > 0 THEN
        AI_COMPLETE(
          ''claude-3-5-sonnet'',
          CONCAT(
            ''Analyze customer segment and respond with valid JSON only:\\n'',
            ''Segment: '', segment_name, ''\\n'',
            ''Customers: '', tc.customer_count, ''\\n'',
            ''MRR: $'', tc.total_mrr, '' (avg $'', tc.avg_revenue, '')\\n'',
            ''Usage: '', COALESCE(su.active_users, 0), '' active, '', COALESCE(su.total_events, 0), '' events\\n'',
            ''Support: '', COALESCE(ss.total_tickets, 0), '' tickets, '', COALESCE(ss.avg_satisfaction, 0), ''/5 satisfaction\\n\\n'',
            ''JSON: {"risk_level":"low/medium/high/critical","key_insight":"main_finding","recommendation":"action"}''
          )
        )
      ELSE NULL
    END as ai_segment_analysis
  FROM (
    SELECT 
      COUNT(*) as customer_count,
      SUM(monthly_revenue) as total_mrr,
      ROUND(AVG(monthly_revenue), 0) as avg_revenue,
      LISTAGG(DISTINCT plan_type, '', '') as plan_mix
    FROM target_customers
  ) tc
  CROSS JOIN segment_usage su
  CROSS JOIN segment_support ss
)
SELECT 
  (OBJECT_CONSTRUCT(
    ''segment_name'', segment_name,
    ''customer_ids_input'', customer_ids_string,
    ''segment_metrics'', OBJECT_CONSTRUCT(
      ''customer_count'', customer_count,
      ''total_mrr'', total_mrr,
      ''avg_revenue_per_customer'', avg_revenue,
      ''plan_mix'', plan_mix,
      ''active_users'', COALESCE(active_users, 0),
      ''avg_session_duration'', COALESCE(avg_session_duration, 0),
      ''support_satisfaction'', COALESCE(avg_satisfaction, 0)
    ),
    ''ai_insights'', TRY_PARSE_JSON(ai_segment_analysis),
    ''raw_ai_response'', ai_segment_analysis,
    ''processing_mode'', ''agent_compatible_analysis'',
    ''node_name'', ''ai_customer_segment_analyzer_v2'',
    ''analysis_timestamp'', CURRENT_TIMESTAMP()
  ))::VARIANT as result
FROM segment_summary
';

-- ============================================================================
-- 2. AI_ANALYZE_CUSTOMER_CONTENT
-- Used by: CONTENT_AGENT (CUSTOMER_CONTENT_ANALYZER tool)
-- Purpose: Sentiment analysis, feedback analysis, support ticket insights
-- ============================================================================

CREATE OR REPLACE FUNCTION CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_CONTENT("CUSTOMER_IDS_STRING" VARCHAR, "ANALYSIS_TYPE" VARCHAR DEFAULT 'recent_support_tickets')
RETURNS VARIANT
LANGUAGE SQL
AS '
WITH parsed_customer_ids AS (
  -- Parse comma-separated string into individual customer IDs
  SELECT 
    TRIM(VALUE) as customer_id
  FROM TABLE(SPLIT_TO_TABLE(customer_ids_string, '',''))
),
target_tickets AS (
  SELECT 
    st.customer_id,
    st.ticket_text,
    st.category,
    st.priority,
    st.satisfaction_score,
    st.created_date
  FROM support_tickets st
  INNER JOIN parsed_customer_ids pci ON st.customer_id = pci.customer_id
  WHERE st.created_date >= CURRENT_DATE() - 365 - 90  -- Handle 365-day data offset
  ORDER BY st.created_date DESC
  LIMIT 10  -- Focus on most recent tickets only
),
content_summary AS (
  SELECT 
    COUNT(*) as total_tickets,
    COUNT(DISTINCT customer_id) as customers_with_tickets,
    ROUND(AVG(satisfaction_score), 2) as avg_satisfaction,
    COUNT(CASE WHEN priority IN (''high'', ''critical'') THEN 1 END) as urgent_tickets,
    LISTAGG(DISTINCT category, '', '') as ticket_categories,
    -- Combine recent ticket text for AI analysis (limit to avoid token limits)
    SUBSTRING(LISTAGG(ticket_text, '' | ''), 1, 1000) as combined_ticket_text
  FROM target_tickets
),
ai_content_analysis AS (
  SELECT 
    cs.*,
    -- Fast AI analysis on limited ticket content
    CASE 
      WHEN cs.total_tickets > 0 THEN
        AI_COMPLETE(
          ''claude-3-5-sonnet'',
          CONCAT(
            ''Analyze customer feedback: '', analysis_type, ''\\n'',
            ''Tickets: '', cs.total_tickets, '' ('', cs.urgent_tickets, '' urgent)\\n'',
            ''Satisfaction: '', cs.avg_satisfaction, ''/5\\n'',
            ''Categories: '', cs.ticket_categories, ''\\n'',
            ''Content: '', cs.combined_ticket_text, ''\\n\\n'',
            ''JSON: {"sentiment":"positive/neutral/negative","urgency":"low/medium/high","key_issue":"main_problem","action_needed":"recommendation"}''
          )
        )
      ELSE NULL
    END as ai_content_insights
  FROM content_summary cs
)
SELECT 
  (OBJECT_CONSTRUCT(
    ''analysis_type'', analysis_type,
    ''customer_ids_input'', customer_ids_string,
    ''content_metrics'', OBJECT_CONSTRUCT(
      ''total_tickets'', total_tickets,
      ''customers_affected'', customers_with_tickets,
      ''avg_satisfaction'', avg_satisfaction,
      ''urgent_tickets'', urgent_tickets,
      ''ticket_categories'', ticket_categories
    ),
    ''ai_content_insights'', TRY_PARSE_JSON(ai_content_insights),
    ''raw_ai_response'', ai_content_insights,
    ''processing_mode'', ''agent_compatible_analysis'',
    ''node_name'', ''ai_content_analyzer_v2'',
    ''analysis_timestamp'', CURRENT_TIMESTAMP()
  ))::VARIANT as result
FROM ai_content_analysis
';

-- ============================================================================
-- 3. AI_PREDICT_CHURN_RISK
-- Used by: DATA_ANALYST_AGENT (CHURN_RISK_PREDICTOR tool)
-- Purpose: Usage patterns, engagement metrics, churn risk assessment
-- ============================================================================

CREATE OR REPLACE FUNCTION CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_PREDICT_CHURN_RISK("CUSTOMER_IDS_STRING" VARCHAR, "ANALYSIS_DAYS" NUMBER(38,0) DEFAULT 30)
RETURNS VARIANT
LANGUAGE SQL
AS '
WITH parsed_customer_ids AS (
  -- Parse comma-separated string into individual customer IDs
  SELECT 
    TRIM(VALUE) as customer_id
  FROM TABLE(SPLIT_TO_TABLE(customer_ids_string, '',''))
),
target_customers AS (
  SELECT 
    c.customer_id,
    c.plan_type,
    c.monthly_revenue,
    c.company_size,
    c.industry,
    c.status,
    DATEDIFF(''day'', c.signup_date, CURRENT_DATE()) as customer_age_days
  FROM customers c
  INNER JOIN parsed_customer_ids pci ON c.customer_id = pci.customer_id
),
behavior_metrics AS (
  SELECT 
    COUNT(DISTINCT u.customer_id) as active_customers,
    COUNT(*) as total_events,
    COUNT(DISTINCT u.event_date) as active_days,
    ROUND(AVG(u.session_duration_minutes), 2) as avg_session_duration,
    SUM(u.actions_count) as total_actions,
    MAX(u.event_date) as last_activity_date,
    COALESCE(DATEDIFF(''day'', MAX(u.event_date), CURRENT_DATE()), 999) as days_since_last_activity
  FROM usage_events u
  INNER JOIN parsed_customer_ids pci ON u.customer_id = pci.customer_id
  WHERE u.event_date >= CURRENT_DATE() - 365 - analysis_days  -- Handle data offset
),
churn_risk_calculation AS (
  SELECT 
    tc.customer_count,
    tc.total_mrr,
    tc.avg_revenue,
    tc.plan_mix,
    bm.active_customers,
    bm.total_events,
    bm.avg_session_duration,
    bm.days_since_last_activity,
    -- Calculate engagement and risk scores
    ROUND((bm.active_customers::FLOAT / GREATEST(tc.customer_count, 1)) * 100, 1) as engagement_rate,
    CASE 
      WHEN bm.days_since_last_activity > 300 THEN 85
      WHEN bm.days_since_last_activity > 200 THEN 65
      WHEN bm.avg_session_duration < 10 THEN 45
      ELSE 25
    END as churn_risk_score,
    -- AI analysis with proper input validation
    CASE 
      WHEN tc.customer_count > 0 THEN
        AI_COMPLETE(
          ''claude-3-5-sonnet'',
          CONCAT(
            ''Analyze customer behavior data and respond with valid JSON only:\\n'',
            ''Segment: '', tc.customer_count, '' customers, $'', tc.total_mrr, '' MRR\\n'',
            ''Activity: '', COALESCE(bm.active_customers, 0), ''/'', tc.customer_count, '' active\\n'',
            ''Usage: '', COALESCE(bm.total_events, 0), '' events, '', COALESCE(bm.avg_session_duration, 0), ''min avg session\\n'',
            ''Last activity: '', bm.days_since_last_activity, '' days ago\\n\\n'',
            ''JSON: {"engagement":"high/medium/low","churn_risk":"low/medium/high/critical","primary_concern":"main_issue","intervention":"action"}''
          )
        )
      ELSE NULL
    END as ai_behavior_insights
  FROM (
    SELECT 
      COUNT(*) as customer_count,
      SUM(monthly_revenue) as total_mrr,
      ROUND(AVG(monthly_revenue), 0) as avg_revenue,
      LISTAGG(DISTINCT plan_type, '', '') as plan_mix
    FROM target_customers
  ) tc
  CROSS JOIN behavior_metrics bm
)
SELECT 
  (OBJECT_CONSTRUCT(
    ''customer_ids_input'', customer_ids_string,
    ''analysis_period_days'', analysis_days,
    ''behavior_metrics'', OBJECT_CONSTRUCT(
      ''customer_count'', customer_count,
      ''total_mrr'', total_mrr,
      ''avg_revenue_per_customer'', avg_revenue,
      ''plan_mix'', plan_mix,
      ''active_customers'', COALESCE(active_customers, 0),
      ''engagement_rate_percent'', engagement_rate,
      ''total_events'', COALESCE(total_events, 0),
      ''avg_session_duration'', COALESCE(avg_session_duration, 0),
      ''days_since_last_activity'', days_since_last_activity
    ),
    ''churn_assessment'', OBJECT_CONSTRUCT(
      ''churn_risk_score'', churn_risk_score,
      ''risk_level'', CASE 
        WHEN churn_risk_score >= 80 THEN ''critical''
        WHEN churn_risk_score >= 60 THEN ''high''
        WHEN churn_risk_score >= 40 THEN ''medium''
        ELSE ''low''
      END,
      ''engagement_status'', CASE 
        WHEN engagement_rate >= 80 THEN ''highly_engaged''
        WHEN engagement_rate >= 50 THEN ''moderately_engaged''
        ELSE ''low_engaged''
      END
    ),
    ''ai_behavior_insights'', TRY_PARSE_JSON(ai_behavior_insights),
    ''raw_ai_response'', ai_behavior_insights,
    ''processing_mode'', ''agent_compatible_analysis'',
    ''node_name'', ''ai_behavior_analyzer_v2'',
    ''analysis_timestamp'', CURRENT_TIMESTAMP()
  ))::VARIANT as result
FROM churn_risk_calculation
';

-- ============================================================================
-- VERIFY
-- ============================================================================
SHOW USER FUNCTIONS IN SCHEMA CUSTOMER_INTELLIGENCE_DB.PUBLIC;


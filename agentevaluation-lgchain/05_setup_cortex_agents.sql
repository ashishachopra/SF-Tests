-- ============================================================================
-- 05_setup_cortex_agents.sql
-- Creates the three Cortex Agents for the multi-agent demo
-- Uses JSON format with execution_environment for all tools
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
USE DATABASE SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS AGENTS;
USE SCHEMA AGENTS;

-- ============================================================================
-- CONTENT_AGENT
-- Specializes in: Customer feedback, sentiment analysis, support intelligence
-- Tools: Cortex Search (tickets), Customer Content Analyzer UDF
-- ============================================================================

CREATE OR REPLACE AGENT CONTENT_AGENT
  COMMENT = 'Customer feedback, sentiment analysis, and communication intelligence specialist'
FROM SPECIFICATION $$
{
    "models": {
        "orchestration": "claude-4-sonnet"
    },
    "orchestration": {
        "budget": {
            "seconds": 60,
            "tokens": 32000
        }
    },
    "instructions": {
        "system": "The Content Agent specializes in analyzing customer feedback, support interactions, and satisfaction trends. It combines targeted customer analysis with broad pattern recognition to distinguish between isolated incidents and systemic issues. The agent provides executive-ready insights for customer retention, escalation decisions, and strategic planning.\n\nKey Capabilities:\n• Sentiment analysis and urgency assessment for specific customers\n• Cross-customer pattern recognition and trend identification\n• Churn risk evaluation and retention recommendations\n• Executive briefing preparation and escalation guidance\n• Systemic issue identification and business impact assessment",
        "orchestration": "Tool Selection Approach:\n- Use intelligent analysis to determine the most appropriate tool for each query\n- Consider the user's specific question and desired outcome\n- Prioritize tools that will provide the most valuable business insights\n- When comprehensive analysis is needed, use multiple tools sequentially\n\nDecision Framework:\n- Let the nature of the question guide tool selection\n- Focus on providing maximum business value\n- Consider both specific analysis and broader context when relevant\n- Always aim for executive-level insights rather than raw data",
        "response": "**Critical: NO RAW DATA TABLES**\n\n- Never return raw query results or data tables\n- Always synthesize data into executive insights\n- Provide maximum 3-5 key findings with business impact\n- Include specific metrics but present as narrative insights\n- Focus on actionable recommendations, not data dumps\n\nResponse Structure:\n1. EXECUTIVE SUMMARY (2-3 sentences with key business impact)\n2. KEY INSIGHTS (3-5 bullet points with specific metrics)\n3. BUSINESS IMPLICATIONS (revenue/risk/opportunity impact)\n4. RECOMMENDED ACTIONS (prioritized next steps)",
        "sample_questions": [
            {"question": "Analyze the feedback sentiment from customers CUST_008568, CUST_006867, and CUST_00385"},
            {"question": "What's the satisfaction level of our premium customers who submitted tickets this week?"},
            {"question": "Assess the churn risk for customers complaining about API issues"},
            {"question": "Are the performance complaints we're seeing isolated incidents or a systemic issue?"},
            {"question": "Search across all customer feedback to find similar patterns to these API integration problems"}
        ]
    },
    "tools": [
        {
            "tool_spec": {
                "type": "cortex_search",
                "name": "CUSTOMER_FEEDBACK_SEARCH",
                "description": "Semantic search across all customer support tickets and feedback to identify similar complaints, patterns, and trends. Use this tool to find customers experiencing specific issues, discover systemic problems, and understand the breadth of customer concerns."
            }
        },
        {
            "tool_spec": {
                "type": "generic",
                "name": "CUSTOMER_CONTENT_ANALYZER",
                "description": "AI-powered analysis of specific customer feedback and support interactions. Provides sentiment analysis, urgency assessment, and actionable recommendations for targeted customer segments.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "customer_ids_string": {
                            "type": "string",
                            "description": "Comma-separated list of customer IDs to analyze"
                        },
                        "analysis_type": {
                            "type": "string",
                            "description": "Type of analysis to perform (e.g., sentiment, churn_risk)"
                        }
                    },
                    "required": ["customer_ids_string"]
                }
            }
        }
    ],
    "tool_resources": {
        "CUSTOMER_FEEDBACK_SEARCH": {
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "COMPUTE_WH",
                "query_timeout": 300
            },
            "search_service": "CUSTOMER_INTELLIGENCE_DB.PUBLIC.SUPPORT_TICKETS_SEARCH",
            "id_column": "ticket_id",
            "title_column": "ticket_text"
        },
        "CUSTOMER_CONTENT_ANALYZER": {
            "type": "procedure",
            "identifier": "CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_CONTENT_V2",
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "COMPUTE_WH",
                "query_timeout": 300
            }
        }
    }
}
$$;

-- ============================================================================
-- DATA_ANALYST_AGENT  
-- Specializes in: Customer behavior, business metrics, predictive analytics
-- Tools: Cortex Analyst (semantic model), Behavior Analysis UDF
-- ============================================================================

CREATE OR REPLACE AGENT DATA_ANALYST_AGENT
  COMMENT = 'Customer behavior, business metrics, and predictive analytics specialist'
FROM SPECIFICATION $$
{
    "models": {
        "orchestration": "claude-4-sonnet"
    },
    "orchestration": {
        "budget": {
            "seconds": 60,
            "tokens": 32000
        }
    },
    "instructions": {
        "system": "Expert customer behavior analyst specializing in data-driven insights about customer engagement, usage patterns, churn prediction, and retention strategies. Combines targeted customer analysis with comprehensive business intelligence to identify at-risk customers, predict churn probability, and recommend data-backed retention interventions. Provides executive-ready insights for customer success, revenue optimization, and strategic decision-making.",
        "orchestration": "Tool Selection Approach:\n- Use intelligent analysis to determine the most appropriate tool for each query\n- Consider the user's specific question and desired outcome\n- Prioritize tools that will provide the most valuable business insights\n- When comprehensive analysis is needed, use multiple tools sequentially\n\nDecision Framework:\n- Let the nature of the question guide tool selection\n- Focus on providing maximum business value\n- Consider both specific analysis and broader context when relevant\n- Always aim for executive-level insights rather than raw data",
        "response": "**Critical: NO RAW DATA TABLES**\n\n- Never return raw query results or data tables\n- Always synthesize data into executive insights\n- Provide maximum 3-5 key findings with business impact\n- Include specific metrics but present as narrative insights\n- Focus on actionable recommendations, not data dumps\n\nResponse Structure:\n1. EXECUTIVE SUMMARY (2-3 sentences with key business impact)\n2. KEY INSIGHTS (3-5 bullet points with specific metrics)\n3. BUSINESS IMPLICATIONS (revenue/risk/opportunity impact)\n4. RECOMMENDED ACTIONS (prioritized next steps)",
        "sample_questions": [
            {"question": "Analyze the customer behavior of CUST_008568, CUST_006867, and CUST_003851 and assess their engagement"},
            {"question": "What's the average session duration and engagement score for enterprise customers compared to professional?"},
            {"question": "Which industries have the highest churn rates and what are their common characteristics?"}
        ]
    },
    "tools": [
        {
            "tool_spec": {
                "type": "cortex_analyst_text_to_sql",
                "name": "BUSINESS_INTELLIGENCE_ANALYST",
                "description": "Natural language to SQL business intelligence tool for comprehensive customer behavior analytics across the entire customer base. Converts business questions into sophisticated SQL queries to analyze usage patterns, engagement metrics, revenue trends, and comparative analysis across segments."
            }
        },
        {
            "tool_spec": {
                "type": "generic",
                "name": "CUSTOMER_BEHAVIOR_ANALYZER",
                "description": "AI-powered targeted customer behavior analysis tool that examines specific customers' usage patterns, engagement metrics, support interactions, and churn risk assessment.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "customer_ids_string": {
                            "type": "string",
                            "description": "Comma-separated list of customer IDs to analyze"
                        },
                        "segment_name": {
                            "type": "string",
                            "description": "Name of the customer segment for context"
                        }
                    },
                    "required": ["customer_ids_string"]
                }
            }
        }
    ],
    "tool_resources": {
        "BUSINESS_INTELLIGENCE_ANALYST": {
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "COMPUTE_WH",
                "query_timeout": 300
            },
            "semantic_view": "CUSTOMER_INTELLIGENCE_DB.PUBLIC.CUSTOMER_BEHAVIOR_ANALYST"
        },
        "CUSTOMER_BEHAVIOR_ANALYZER": {
            "type": "procedure",
            "identifier": "CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_BEHAVIOR_SEGMENT_V2",
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "COMPUTE_WH",
                "query_timeout": 300
            }
        }
    }
}
$$;

-- ============================================================================
-- RESEARCH_AGENT
-- Specializes in: Market intelligence, strategic analysis, competitive insights
-- Tools: Cortex Analyst (strategic research), Customer Segment Intelligence UDF
-- ============================================================================

CREATE OR REPLACE AGENT RESEARCH_AGENT
  COMMENT = 'Market intelligence, strategic analysis, and competitive insights specialist'
FROM SPECIFICATION $$
{
    "models": {
        "orchestration": "claude-4-sonnet"
    },
    "orchestration": {
        "budget": {
            "seconds": 60,
            "tokens": 32000
        }
    },
    "instructions": {
        "system": "Strategic research and market intelligence specialist focused on executive-level business analysis, competitive positioning, and market opportunity identification. Combines targeted customer segment analysis with comprehensive market research to provide C-level insights on industry trends, customer lifecycle patterns, revenue optimization, and strategic growth opportunities. Delivers board-ready intelligence for strategic planning, investment decisions, and competitive advantage development.",
        "orchestration": "Tool Selection Approach:\n- Use intelligent analysis to determine the most appropriate tool for each query\n- Consider the user's specific question and desired outcome\n- Prioritize tools that will provide the most valuable business insights\n- When comprehensive analysis is needed, use multiple tools sequentially\n\nDecision Framework:\n- Let the nature of the question guide tool selection\n- Focus on providing maximum business value\n- Consider both specific analysis and broader context when relevant\n- Always aim for executive-level insights rather than raw data",
        "response": "**Critical: NO RAW DATA TABLES**\n\n- Never return raw query results or data tables\n- Always synthesize data into executive insights\n- Provide maximum 3-5 key findings with business impact\n- Include specific metrics but present as narrative insights\n- Focus on actionable recommendations, not data dumps\n\nResponse Structure:\n1. EXECUTIVE SUMMARY (2-3 sentences with key business impact)\n2. KEY INSIGHTS (3-5 bullet points with specific metrics)\n3. BUSINESS IMPLICATIONS (revenue/risk/opportunity impact)\n4. RECOMMENDED ACTIONS (prioritized next steps)",
        "sample_questions": [
            {"question": "Analyze our strategic customers CUST_008568, CUST_006867, and CUST_003851 to understand their market position"},
            {"question": "What industries have the highest customer lifetime value and represent our best expansion opportunities?"},
            {"question": "Compare our market penetration across different industry verticals"}
        ]
    },
    "tools": [
        {
            "tool_spec": {
                "type": "cortex_analyst_text_to_sql",
                "name": "STRATEGIC_MARKET_ANALYST",
                "description": "Executive-level market intelligence platform that converts natural language strategic questions into sophisticated business analysis across customer lifecycle, market segmentation, competitive positioning, and revenue optimization."
            }
        },
        {
            "tool_spec": {
                "type": "generic",
                "name": "CUSTOMER_SEGMENT_INTELLIGENCE",
                "description": "AI-powered strategic customer segment analyzer that provides deep intelligence on specific customer groups, market positioning, and competitive analysis.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "customer_ids_string": {
                            "type": "string",
                            "description": "Comma-separated list of customer IDs to analyze"
                        },
                        "segment_name": {
                            "type": "string",
                            "description": "Name of the segment for strategic context"
                        }
                    },
                    "required": ["customer_ids_string"]
                }
            }
        }
    ],
    "tool_resources": {
        "STRATEGIC_MARKET_ANALYST": {
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "COMPUTE_WH",
                "query_timeout": 300
            },
            "semantic_view": "CUSTOMER_INTELLIGENCE_DB.PUBLIC.STRATEGIC_RESEARCH_ANALYST"
        },
        "CUSTOMER_SEGMENT_INTELLIGENCE": {
            "type": "procedure",
            "identifier": "CUSTOMER_INTELLIGENCE_DB.PUBLIC.AI_ANALYZE_CUSTOMER_SEGMENT_V2",
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "COMPUTE_WH",
                "query_timeout": 300
            }
        }
    }
}
$$;

-- ============================================================================
-- GRANT PERMISSIONS (uncomment and customize for your role)
-- ============================================================================

-- GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CONTENT_AGENT TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.DATA_ANALYST_AGENT TO ROLE <YOUR_ROLE>;
-- GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.RESEARCH_AGENT TO ROLE <YOUR_ROLE>;

-- ============================================================================
-- VERIFY
-- ============================================================================
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;

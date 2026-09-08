import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Fraud Detection", layout="wide")
st.title("Claims Fraud Detection Dashboard")

session = get_active_session()

@st.cache_data
def load_suspicious_policies():
    return session.sql("""
        SELECT
          icf.policy_number,
          icf.fraud_reported,
          knn.sourcenodeid AS similar_to_policy,
          knn.score AS similarity_score
        FROM ER_DEMO.PUBLIC.INSURANCE_CLAIMS_FULL icf
        JOIN ER_DEMO.PUBLIC.CLAIMS_KNN_SIMILARITY knn
          ON CAST(icf.policy_number AS VARCHAR) = knn.targetnodeid
        WHERE knn.score = 1
          AND icf.fraud_reported <> 'Y'
          AND EXISTS (
            SELECT 1
            FROM ER_DEMO.PUBLIC.INSURANCE_CLAIMS_FULL icf_src
            WHERE CAST(icf_src.policy_number AS VARCHAR) = knn.sourcenodeid
              AND icf_src.fraud_reported = 'Y'
          )
    """).to_pandas()

@st.cache_data
def load_fraud_stats():
    return session.sql("""
        SELECT fraud_reported, COUNT(*) AS count
        FROM ER_DEMO.PUBLIC.INSURANCE_CLAIMS_FULL
        GROUP BY fraud_reported
    """).to_pandas()

@st.cache_data
def load_similarity_distribution():
    return session.sql("""
        SELECT ROUND(score, 2) AS score_bucket, COUNT(*) AS count
        FROM ER_DEMO.PUBLIC.CLAIMS_KNN_SIMILARITY
        GROUP BY ROUND(score, 2)
        ORDER BY score_bucket DESC
    """).to_pandas()

@st.cache_data
def load_high_similarity_pairs():
    return session.sql("""
        SELECT sourcenodeid, targetnodeid, score
        FROM ER_DEMO.PUBLIC.CLAIMS_KNN_SIMILARITY
        WHERE score >= 0.9
        ORDER BY score DESC
        LIMIT 500
    """).to_pandas()

suspicious_df = load_suspicious_policies()
fraud_stats = load_fraud_stats()
similarity_dist = load_similarity_distribution()
high_sim_pairs = load_high_similarity_pairs()

tab1, tab2, tab3 = st.tabs(["Suspicious Policies", "Overview", "Similarity Analysis"])

with tab1:
    st.subheader("Policies Flagged as Potential Fraud")
    st.warning(f"Found **{len(suspicious_df)}** policies with identical patterns to known fraud cases")
    
    st.dataframe(suspicious_df, use_container_width=True, hide_index=True)
    
    st.download_button(
        "Download Suspicious Policies CSV",
        suspicious_df.to_csv(index=False),
        "suspicious_policies.csv",
        "text/csv"
    )

with tab2:
    col1, col2, col3 = st.columns(3)
    total = fraud_stats['COUNT'].sum()
    fraud_count = fraud_stats[fraud_stats['FRAUD_REPORTED'] == 'Y']['COUNT'].sum() if 'Y' in fraud_stats['FRAUD_REPORTED'].values else 0
    
    col1.metric("Total Policies", f"{total:,}")
    col2.metric("Known Fraud Cases", f"{fraud_count:,}")
    col3.metric("Newly Flagged", len(suspicious_df))
    
    st.subheader("Fraud Distribution")
    st.bar_chart(fraud_stats.set_index('FRAUD_REPORTED')['COUNT'])

with tab3:
    st.subheader("Similarity Score Distribution")
    st.bar_chart(similarity_dist.set_index('SCORE_BUCKET')['COUNT'])
    
    st.subheader("High Similarity Pairs (≥0.9)")
    min_score = st.slider("Minimum Score", 0.9, 1.0, 0.95, 0.01)
    filtered = high_sim_pairs[high_sim_pairs['SCORE'] >= min_score]
    st.dataframe(filtered, use_container_width=True)
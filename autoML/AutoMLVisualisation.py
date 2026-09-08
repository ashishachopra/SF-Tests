import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(page_title="ML Model Observability", layout="wide")
st.title("ML Model Observability Dashboard")

session = get_active_session()

st.sidebar.header("Settings")
days_back = st.sidebar.slider("Days to look back", 1, 30, 7)

monitors = {
    "v1_wh": "CHURN_MODEL_MONITOR",
    "v2": "CHURN_MODEL_MONITOR_NEW"
}
selected_version = st.sidebar.selectbox("Model Version", list(monitors.keys()))
monitor_name = monitors[selected_version]

col1, col2 = st.columns(2)

with col1:
    st.subheader("Stat Metrics (COUNT)")
    stat_query = f"""
    SELECT * FROM TABLE(MODEL_MONITOR_STAT_METRIC(
        '{monitor_name}', 'COUNT', 'PREDICTED_CHURN', '1 DAY',
        DATEADD('day', -{days_back}, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()))
    ORDER BY EVENT_TIMESTAMP
    """
    stat_df = session.sql(stat_query).to_pandas()
    if not stat_df.empty:
        st.line_chart(stat_df.set_index('EVENT_TIMESTAMP')['METRIC_VALUE'])
        st.dataframe(stat_df, use_container_width=True)
    else:
        st.info("No stat metrics available yet")

with col2:
    st.subheader("Drift Metrics")
    drift_query = f"""
    SELECT * FROM TABLE(MODEL_MONITOR_DRIFT_METRIC(
        '{monitor_name}', 'DIFFERENCE_OF_MEANS', 'PREDICTED_CHURN', '1 DAY',
        DATEADD('day', -{days_back}, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()))
    ORDER BY EVENT_TIMESTAMP
    """
    drift_df = session.sql(drift_query).to_pandas()
    if not drift_df.empty:
        st.line_chart(drift_df.set_index('EVENT_TIMESTAMP')['METRIC_VALUE'])
        st.dataframe(drift_df, use_container_width=True)
    else:
        st.info("No drift metrics available yet")

st.subheader("Performance Metrics (PRECISION)")
perf_query = f"""
SELECT 
    'v1_wh' as MODEL_VERSION, * 
FROM TABLE(MODEL_MONITOR_PERFORMANCE_METRIC(
    'CHURN_MODEL_MONITOR', 'PRECISION', '1 DAY',
    DATEADD('day', -{days_back}, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()))
UNION ALL
SELECT 
    'v2' as MODEL_VERSION, * 
FROM TABLE(MODEL_MONITOR_PERFORMANCE_METRIC(
    'CHURN_MODEL_MONITOR_NEW', 'PRECISION', '1 DAY',
    DATEADD('day', -{days_back}, CURRENT_TIMESTAMP()), CURRENT_TIMESTAMP()))
ORDER BY EVENT_TIMESTAMP, MODEL_VERSION
"""
perf_df = session.sql(perf_query).to_pandas()
if not perf_df.empty:
    st.line_chart(perf_df.pivot(index='EVENT_TIMESTAMP', columns='MODEL_VERSION', values='METRIC_VALUE'))
    st.dataframe(perf_df, use_container_width=True)
else:
    st.info("No performance metrics available yet")

st.subheader("Alerts")
alerts_df = session.sql("SELECT * FROM TEST_NOTIFICATION ORDER BY created_at DESC LIMIT 10").to_pandas()
if not alerts_df.empty:
    st.dataframe(alerts_df, use_container_width=True)
else:
    st.success("No alerts triggered")

st.subheader("Model Registry")
models_df = session.sql("SHOW MODELS LIKE 'QS_CustomerChurn_classifier'").to_pandas()
st.dataframe(models_df, use_container_width=True)

st.subheader("Monitor Status")
monitors_df = session.sql("SHOW MODEL MONITORS").to_pandas()
st.dataframe(monitors_df, use_container_width=True)
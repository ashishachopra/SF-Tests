import streamlit as st
import altair as alt
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Customer Review Analysis", layout="wide")
st.title("Customer Review Sentiment Analysis")

session = get_active_session()

@st.cache_data
def load_data():
    query = """
    WITH files AS (
      SELECT REPLACE(REGEXP_SUBSTR(file_url, '[^/]+$'), '%2e', '.') as filename
      FROM DIRECTORY('@ER_DEMO.PUBLIC.ML_STAGE')
      WHERE filename LIKE '%.docx'
    ),
    parsed AS (
      SELECT filename,
        SNOWFLAKE.CORTEX.PARSE_DOCUMENT(@ER_DEMO.PUBLIC.ML_STAGE, filename, {'mode': 'layout'}):content AS layout
      FROM files
    ),
    extracted AS (
      SELECT filename,
        REGEXP_SUBSTR(layout, 'Product: (.*?)\\n', 1, 1, 'e') as product,
        REGEXP_SUBSTR(layout, 'Date: (202[0-9]-[0-9]{2}-[0-9]{2})', 1, 1, 'e') as date,
        REGEXP_SUBSTR(layout, '## Customer Review\\n([\\s\\S]*?)$', 1, 1, 'es') as customer_review
      FROM parsed
    )
    SELECT product, date,
      SNOWFLAKE.CORTEX.TRANSLATE(customer_review, '', 'en') as translated_review,
      SNOWFLAKE.CORTEX.SUMMARIZE(SNOWFLAKE.CORTEX.TRANSLATE(customer_review, '', 'en')) as summary,
      SNOWFLAKE.CORTEX.SENTIMENT(SNOWFLAKE.CORTEX.TRANSLATE(customer_review, '', 'en')) as sentiment_score
    FROM extracted
    WHERE product IS NOT NULL
    ORDER BY date
    """
    return session.sql(query).to_pandas()

with st.spinner("Loading and analyzing reviews..."):
    df = load_data()

st.sidebar.header("Filters")
products = st.sidebar.multiselect("Select Products", df['PRODUCT'].unique(), default=df['PRODUCT'].unique())
filtered_df = df[df['PRODUCT'].isin(products)]

col1, col2, col3, col4 = st.columns(4)
col1.metric("Total Reviews", len(filtered_df))
col2.metric("Avg Sentiment", f"{filtered_df['SENTIMENT_SCORE'].mean():.2f}")
col3.metric("Positive Reviews", len(filtered_df[filtered_df['SENTIMENT_SCORE'] >= 0]))
col4.metric("Negative Reviews", len(filtered_df[filtered_df['SENTIMENT_SCORE'] < 0]))

st.subheader("Sentiment Over Time")
time_chart = alt.Chart(filtered_df).mark_bar(size=15).encode(
    x=alt.X('DATE:T', axis=alt.Axis(format='%Y-%m-%d', labelAngle=90)),
    y=alt.Y('SENTIMENT_SCORE:Q'),
    color=alt.condition(alt.datum.SENTIMENT_SCORE >= 0, alt.value('#2ecc71'), alt.value('#e74c3c')),
    tooltip=['PRODUCT:N', 'DATE:T', 'SENTIMENT_SCORE:Q']
).properties(height=400)
st.altair_chart(time_chart, use_container_width=True)

st.subheader("Average Sentiment by Product")
product_chart = alt.Chart(filtered_df).mark_bar().encode(
    y=alt.Y('PRODUCT:N', sort='-x'),
    x=alt.X('mean(SENTIMENT_SCORE):Q', title='Average Sentiment'),
    color=alt.condition(alt.datum.mean_SENTIMENT_SCORE >= 0, alt.value('#2ecc71'), alt.value('#e74c3c')),
    tooltip=['PRODUCT:N', 'mean(SENTIMENT_SCORE):Q', 'count():Q']
).properties(height=400)
st.altair_chart(product_chart, use_container_width=True)

st.subheader("Review Details")
st.dataframe(filtered_df[['PRODUCT', 'DATE', 'SUMMARY', 'SENTIMENT_SCORE']], use_container_width=True)

st.download_button(
    "Download CSV",
    filtered_df[['PRODUCT', 'DATE', 'SUMMARY', 'SENTIMENT_SCORE']].to_csv(index=False).encode('utf-8'),
    "customer_reviews.csv",
    "text/csv"
)
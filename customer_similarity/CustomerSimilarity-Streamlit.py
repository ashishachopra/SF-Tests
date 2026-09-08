import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(page_title="Customer Similarity Network", layout="wide")
st.title("Customer Similarity Network")

session = get_active_session()

@st.cache_data
def load_data():
    matches = session.sql("""
        WITH customers AS (
            SELECT 
                "CUSTOMER_ID",
                UPPER(TRIM("FIRST_NAME" || ' ' || "LAST_NAME")) AS NAME,
                "PHONE",
                "EMAIL"
            FROM ER_DEMO.PUBLIC.CUSTOMER
        )
        SELECT DISTINCT
            a."CUSTOMER_ID" AS CUSTOMER_ID_1,
            b."CUSTOMER_ID" AS CUSTOMER_ID_2,
            a.NAME AS NAME_1,
            b.NAME AS NAME_2,
            a.EMAIL AS EMAIL_1
        FROM customers a
        JOIN customers b
            ON a."CUSTOMER_ID" < b."CUSTOMER_ID"
        WHERE 
            a.EMAIL = b.EMAIL
            OR a.PHONE = b.PHONE
            OR JAROWINKLER_SIMILARITY(a.NAME, b.NAME) >= 85
        LIMIT 100
    """).to_pandas()
    return matches

matches_df = load_data()

nodes = list(set(matches_df['CUSTOMER_ID_1'].tolist() + matches_df['CUSTOMER_ID_2'].tolist()))
node_names = {}
for _, row in matches_df.iterrows():
    node_names[row['CUSTOMER_ID_1']] = row['NAME_1'][:15]
    node_names[row['CUSTOMER_ID_2']] = row['NAME_2'][:15]

col1, col2, col3 = st.columns(3)
with col1:
    st.metric("Nodes", len(nodes))
with col2:
    st.metric("Edges", len(matches_df))
with col3:
    st.metric("Avg Connections", f"{len(matches_df)*2/max(len(nodes),1):.1f}")

graph_lines = ['graph G {', '  layout=neato;', '  overlap=false;', '  node [style=filled, fillcolor=lightblue, shape=ellipse, fontsize=10];', '  edge [color=gray];']

for node_id, name in node_names.items():
    safe_name = name.replace('"', "'").replace('\\', '')
    graph_lines.append(f'  "{node_id}" [label="{safe_name}"];')

for _, row in matches_df.iterrows():
    graph_lines.append(f'  "{row["CUSTOMER_ID_1"]}" -- "{row["CUSTOMER_ID_2"]}";')

graph_lines.append('}')
graph_dot = '\n'.join(graph_lines)

st.subheader("Network Graph")
st.graphviz_chart(graph_dot, use_container_width=True)

st.subheader("Match Details")
st.dataframe(matches_df[['NAME_1', 'NAME_2', 'EMAIL_1']], use_container_width=True, height=300)
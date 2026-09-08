import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.title("Text Processing with Cortex LLMs")

TASKS = {
    "Summarize": "summarize",
    "Translate to Spanish": "translate_es", 
    "Translate to French": "translate_fr",
    "Sentiment Analysis": "sentiment",
}

MODELS = ["llama3.1-8b", "mistral-7b"]

PROMPTS = {
    "summarize": "Summarize concisely:\n\n{text}",
    "translate_es": "Translate to Spanish:\n\n{text}",
    "translate_fr": "Translate to French:\n\n{text}",
    "sentiment": "Analyze sentiment (positive/negative/neutral):\n\n{text}",
}

def cortex_complete(model, prompt):
    escaped_prompt = prompt.replace("'", "''")
    result = session.sql(f"SELECT SNOWFLAKE.CORTEX.COMPLETE('{model}', '{escaped_prompt}') AS RESPONSE").collect()
    return result[0]["RESPONSE"]

col1, col2 = st.columns(2)
with col1:
    task = st.selectbox("Task", list(TASKS.keys()))
with col2:
    model = st.selectbox("Model", MODELS)

text_input = st.text_area("Enter text to process", height=150)

if st.button("Process", type="primary"):
    if text_input.strip():
        with st.spinner("Processing..."):
            task_key = TASKS[task]
            prompt = PROMPTS[task_key].format(text=text_input)
            result = cortex_complete(model, prompt)
        
        st.subheader("Result")
        st.success(result)
    else:
        st.warning("Please enter some text")
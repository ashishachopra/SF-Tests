import streamlit as st
import json
import uuid
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="RAG Data Chatbot", page_icon="💬")
st.title("💬 RAG Data Chatbot")

session = get_active_session()

if "messages" not in st.session_state:
    st.session_state.messages = []

if "session_id" not in st.session_state:
    st.session_state.session_id = str(uuid.uuid4())

for message in st.session_state.messages:
    if message["role"] == "user":
        st.info(f"**You:** {message['content']}")
    else:
        st.success(f"**Assistant:** {message['content']}")
        if "sql" in message:
            with st.expander("View SQL"):
                st.code(message["sql"], language="sql")

with st.form("chat_form", clear_on_submit=True):
    prompt = st.text_input("Ask a question about your data...")
    submitted = st.form_submit_button("Send")

if submitted and prompt:
    st.session_state.messages.append({"role": "user", "content": prompt})
    
    with st.spinner("Querying data..."):
        try:
            result = session.call("rag_query", st.session_state.session_id, prompt)
            data = json.loads(result)
            
            if "error" in data:
                response = f"Error: {data['error']}"
                st.session_state.messages.append({"role": "assistant", "content": response, "sql": data.get('generated_sql', '')})
            else:
                answer = data.get("natural_language_answer", "No answer generated")
                st.session_state.messages.append({
                    "role": "assistant", 
                    "content": answer,
                    "sql": data.get("generated_sql", "")
                })
        except Exception as e:
            st.session_state.messages.append({"role": "assistant", "content": f"Error: {str(e)}"})
    
    st.experimental_rerun()

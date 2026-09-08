import streamlit as st
import json
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="RAG Data Chatbot", page_icon="💬")
st.title("💬 RAG Data Chatbot")

session = get_active_session()

if "messages" not in st.session_state:
    st.session_state.messages = []

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        if "sql" in message:
            with st.expander("View SQL"):
                st.code(message["sql"], language="sql")

if prompt := st.chat_input("Ask a question about your data..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Querying data..."):
            try:
                result = session.call("rag_query", prompt)
                data = json.loads(result)
                
                if "error" in data:
                    response = f"❌ Error: {data['error']}\n\nGenerated SQL:\n```sql\n{data.get('generated_sql', 'N/A')}\n```"
                    st.markdown(response)
                    st.session_state.messages.append({"role": "assistant", "content": response})
                else:
                    answer = data.get("answer", "No answer generated")
                    st.markdown(answer)
                    with st.expander("View SQL & Results"):
                        st.code(data.get("generated_sql", ""), language="sql")
                        if data.get("results"):
                            st.dataframe(data["results"])
                    st.session_state.messages.append({
                        "role": "assistant", 
                        "content": answer,
                        "sql": data.get("generated_sql", "")
                    })
            except Exception as e:
                error_msg = f"❌ Error: {str(e)}"
                st.error(error_msg)
                st.session_state.messages.append({"role": "assistant", "content": error_msg})

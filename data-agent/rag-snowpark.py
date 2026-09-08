import json
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
from langchain.embeddings import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.chat_models import ChatOpenAI
from langchain.prompts import PromptTemplate
import os

# Load API key from Snowflake secrets (set via Snowflake UI or SQL)
OPENAI_API_KEY = os.environ["OPENAI_API_KEY"]

def rag_query(session: Session, session_id: str, question: str) -> str:
    """
    Snowpark stored procedure to run RAG-based NL query over Snowflake data.
    """
    # 1. Retrieve conversation history from Snowflake table
    history_df = session.table("rag_chat_memory").filter(col("session_id") == session_id).order_by(col("created_at"))
    history_records = history_df.collect()
    chat_history = "\n".join([f"{r['ROLE']}: {r['MESSAGE']}" for r in history_records])

    # 2. Get schema context from Snowflake
    tables = session.sql("SHOW TABLES").collect()
    docs = []
    for t in tables:
        table_name = t["name"]
        schema_info = session.sql(f"DESCRIBE TABLE {table_name}").collect()
        schema_str = "\n".join([str(row) for row in schema_info])
        docs.append(f"Table: {table_name}\nSchema:\n{schema_str}")

    # 3. Generate SQL from question + history + schema
    llm = ChatOpenAI(model="gpt-4", temperature=0, openai_api_key=OPENAI_API_KEY)
    sql_prompt = PromptTemplate(
        input_variables=["context", "history", "question"],
        template="""
        You are an expert Snowflake SQL generator.
        Use the schema context and conversation history to write a correct SQL query.
        Schema Context:
        {context}
        Conversation History:
        {history}
        Current Question:
        {question}
        SQL:
        """
    )
    sql_query = llm.predict(sql_prompt.format(
        context="\n".join(docs),
        history=chat_history,
        question=question
    )).strip()

    # 4. Execute SQL
    try:
        result_df = session.sql(sql_query)
        results = result_df.collect()
        columns = result_df.schema.names
    except Exception as e:
        return json.dumps({"error": f"SQL Execution Error: {str(e)}", "generated_sql": sql_query})

    # 5. Convert results to natural language
    nl_prompt = PromptTemplate(
        input_variables=["question", "sql", "columns", "results"],
        template="""
        You are a data analyst. The user asked:
        "{question}"
        The SQL executed was:
        {sql}
        The results (columns: {columns}) are:
        {results}
        Provide a concise, clear natural language answer.
        """
    )
    nl_answer = llm.predict(nl_prompt.format(
        question=question,
        sql=sql_query,
        columns=columns,
        results=results
    ))

    # 6. Save conversation turn to memory table
    session.table("rag_chat_memory").insert([
        (session_id, "user", question),
        (session_id, "assistant", nl_answer)
    ])

    # 7. Return JSON response
    return json.dumps({
        "session_id": session_id,
        "question": question,
        "generated_sql": sql_query,
        "columns": columns,
        "results": [list(r.asDict().values()) for r in results],
        "natural_language_answer": nl_answer
    })

import os
from snowflake.connector import connect
from langchain.embeddings import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.chat_models import ChatOpenAI
from langchain.prompts import PromptTemplate
from langchain.memory import ConversationBufferMemory
from config import *

# Global memory store (per session_id)
session_memories = {}

def get_memory(session_id: str):
    """Retrieve or create a conversation memory for a session."""
    if session_id not in session_memories:
        session_memories[session_id] = ConversationBufferMemory(
            memory_key="chat_history",
            return_messages=True
        )
    return session_memories[session_id]

# Snowflake connection
def get_snowflake_connection():
    return connect(
        user=SNOWFLAKE_USER,
        password=SNOWFLAKE_PASSWORD,
        account=SNOWFLAKE_ACCOUNT,
        warehouse=SNOWFLAKE_WAREHOUSE,
        database=SNOWFLAKE_DATABASE,
        schema=SNOWFLAKE_SCHEMA
    )

# Build vector store from Snowflake schema
def build_vector_store():
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    cursor.execute("SHOW TABLES")
    tables = [row[1] for row in cursor.fetchall()]

    docs = []
    for table in tables:
        cursor.execute(f"DESCRIBE TABLE {table}")
        schema_info = "\n".join([str(r) for r in cursor.fetchall()])
        docs.append(f"Table: {table}\nSchema:\n{schema_info}")

    embeddings = OpenAIEmbeddings(openai_api_key=OPENAI_API_KEY)
    vectorstore = Chroma.from_texts(
        docs,
        embeddings,
        collection_name="snowflake_docs",
        persist_directory="vector_store"
    )
    vectorstore.persist()
    return vectorstore

# Load or create vector store
def get_vector_store():
    if os.path.exists("vector_store"):
        embeddings = OpenAIEmbeddings(openai_api_key=OPENAI_API_KEY)
        return Chroma(
            collection_name="snowflake_docs",
            embedding_function=embeddings,
            persist_directory="vector_store"
        )
    else:
        return build_vector_store()

# Generate SQL from natural language with memory
def generate_sql(question: str, session_id: str):
    vectorstore = get_vector_store()
    retriever_context = "\n".join([doc.page_content for doc in vectorstore.similarity_search(question, k=3)])

    memory = get_memory(session_id)
    chat_history = "\n".join([f"{m.type}: {m.content}" for m in memory.chat_memory.messages])

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
        context=retriever_context,
        history=chat_history,
        question=question
    )).strip()

    memory.chat_memory.add_user_message(question)
    memory.chat_memory.add_ai_message(f"Generated SQL: {sql_query}")

    return sql_query

# Execute SQL safely
def execute_sql(sql: str):
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(sql)
        return cursor.fetchall(), [desc[0] for desc in cursor.description]
    except Exception as e:
        return f"SQL Execution Error: {str(e)}", []

# Convert SQL results to natural language
def results_to_nl(question: str, sql: str, results, columns, session_id: str):
    llm = ChatOpenAI(model="gpt-4", temperature=0, openai_api_key=OPENAI_API_KEY)
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
    answer = llm.predict(nl_prompt.format(
        question=question,
        sql=sql,
        columns=columns,
        results=results
    ))

    memory = get_memory(session_id)
    memory.chat_memory.add_ai_message(answer)

    return answer

from fastapi import FastAPI
from pydantic import BaseModel
from rag_engine import generate_sql, execute_sql, results_to_nl

app = FastAPI(title="Snowflake RAG Conversational Chatbot API")

class QueryRequest(BaseModel):
    session_id: str
    question: str

@app.post("/ask")
def ask_question(req: QueryRequest):
    # Step 1: Generate SQL with memory
    sql_query = generate_sql(req.question, req.session_id)

    # Step 2: Execute SQL
    results, columns = execute_sql(sql_query)

    if isinstance(results, str) and results.startswith("SQL Execution Error"):
        return {
            "session_id": req.session_id,
            "question": req.question,
            "generated_sql": sql_query,
            "error": results
        }

    # Step 3: Convert results to natural language
    nl_answer = results_to_nl(req.question, sql_query, results, columns, req.session_id)

    return {
        "session_id": req.session_id,
        "question": req.question,
        "generated_sql": sql_query,
        "results": results,
        "columns": columns,
        "natural_language_answer": nl_answer
    }

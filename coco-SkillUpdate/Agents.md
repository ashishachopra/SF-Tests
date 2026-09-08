# Project Context for Cortex Code

## Dev Environment Opinions
- **Variables:** Always use the prefix `v_` (e.g., `v_account_id`).
- **Functions:** All Python or Snowpark functions must start with `func_`.
- **Stored Procedures:** All Snowflake procedures must be prefixed with `proc_`.

## Available Skills
- `python-reviewer`: Use for any code review requests for Python/Snowpark files. 
  Location: `.snowflake/cortex/skills/python-reviewer`
- `sql-reviewer`: Use for any code review requests for SQL scripts or DDL. 
  Location: `.snowflake/cortex/skills/sql-reviewer`
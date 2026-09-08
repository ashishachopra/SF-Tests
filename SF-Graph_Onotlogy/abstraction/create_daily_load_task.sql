-- Create a task to load iceberg TM transactions daily at 9 AM
-- Create the task (initially suspended)
CREATE OR REPLACE TASK LOAD_ICEBERG_TM_TRANSACTIONS_TASK
  WAREHOUSE = GBU_A01A0E_FINCRIME_XS_WH
  SCHEDULE = 'USING CRON 0 9 * * * UTC'  -- Runs daily at 9:00 AM UTC
  COMMENT = 'Daily task to load iceberg TM transactions at 9 AM'
AS
BEGIN
  -- Replace this with the actual SQL from load_iceberg_tm_transactions.sql
  -- Or call a stored procedure if your logic is in a procedure
  
  -- Example: If you have the logic inline
  -- INSERT INTO target_table SELECT * FROM source_table WHERE ...;
  
  -- Example: If you have a stored procedure
  -- CALL LOAD_ICEBERG_TM_TRANSACTIONS_PROC();
  
  -- Placeholder - replace with your actual logic
  SELECT 'Task executed at ' || CURRENT_TIMESTAMP()::STRING AS execution_time;
  
END;

-- Resume the task to start scheduling
-- ALTER TASK LOAD_ICEBERG_TM_TRANSACTIONS_TASK RESUME;

-- To check task status:
-- SHOW TASKS LIKE 'LOAD_ICEBERG_TM_TRANSACTIONS_TASK';

-- To view task history:
-- SELECT *
-- FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
--   TASK_NAME => 'LOAD_ICEBERG_TM_TRANSACTIONS_TASK',
--   SCHEDULED_TIME_RANGE_START => DATEADD(DAY, -7, CURRENT_TIMESTAMP())
-- ))
-- ORDER BY SCHEDULED_TIME DESC;

-- To suspend the task:
-- ALTER TASK LOAD_ICEBERG_TM_TRANSACTIONS_TASK SUSPEND;

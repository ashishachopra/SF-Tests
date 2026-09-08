/*
Before running this worksheet, replace <db> and <schema> below with a database name and schema name from your account.
*/

USE DATABASE ER_DEMO;
USE SCHEMA PUBLIC;

/*
# RelationalAI Native App Setup Guide
*/

/*
Note that the `ACCOUNTADMIN` role is used. 
This role is needed for Step 1 and for creating the network rule in Step 4. 
*/

USE ROLE ACCOUNTADMIN;

/*
## Step 1 - Activate the RAI Native App
*/
BEGIN

CREATE OR REPLACE PROCEDURE rai_installation_step()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
def main(session):

    import sys
    import time
    import json
    import itertools


    def poll(f):

        last_message = ""
        dots = itertools.cycle([".", ".", ".", ".", ".", "."])

        def status(message):
            spaces = " " * (len(". " + last_message) - len(message))
            sys.stdout.write("\r" + message + spaces)
            sys.stdout.flush()

        for ctr in itertools.count():
            if ctr % 10 == 0:
                result = f()
                if isinstance(result, str):
                    message = next(dots) + " " + result
                    status(message)
                    last_message = result
                if result is True:
                    status(". Done!")
                    return
            else:
                message = next(dots) + " " + last_message
                status(message)
            time.sleep(0.5)

    def activate():
        try:
            session.sql("CALL RELATIONALAI.APP.ACTIVATE();").collect()
            return True
        except Exception as e:
            if "Unknown user-defined function" in str(e):
                return "Waiting for app installation to complete..."
            else:
                raise e

    poll(activate)

    return "Step completed"
$$;

CALL rai_installation_step();

DROP PROCEDURE rai_installation_step();

RETURN 'Step completed';
END;

BEGIN

CREATE OR REPLACE PROCEDURE rai_installation_step()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
def main(session):

    import sys
    import time
    import json
    import itertools


    def poll(f):

        last_message = ""
        dots = itertools.cycle([".", ".", ".", ".", ".", "."])

        def status(message):
            spaces = " " * (len(". " + last_message) - len(message))
            sys.stdout.write("\r" + message + spaces)
            sys.stdout.flush()

        for ctr in itertools.count():
            if ctr % 10 == 0:
                result = f()
                if isinstance(result, str):
                    message = next(dots) + " " + result
                    status(message)
                    last_message = result
                if result is True:
                    status(". Done!")
                    return
            else:
                message = next(dots) + " " + last_message
                status(message)
            time.sleep(0.5)

    def check():
        result = session.sql("CALL RELATIONALAI.APP.SERVICE_STATUS();").collect()
        status = json.loads(result[0]["SERVICE_STATUS"])[0]["message"]
        if status is None:
            status = ""
        elif status.startswith("UNKNOWN"):
            status = "Working"
        elif status.startswith("Readiness probe"):
            status = "Almost done"
        elif status == "Running":
            return True
        else:
            return status + "..."

    poll(check)

    return "Step completed"
$$;

CALL rai_installation_step();

DROP PROCEDURE rai_installation_step();

RETURN 'Step completed';
END;

/*
## Step 2 - Setting up Change Data Capture
*/
CALL RELATIONALAI.APP.RESUME_CDC();

/*
## Step 3 - Creating user roles
*/
/*
The RAI Native App comes with a set of Snowflake application roles for
managing access to the app. Application roles can't be granted to users
directly, and must be granted to Snowflake database roles instead.
*/
-- Create a rai_admin role for full admin access to the RAI Native App.
CREATE ROLE rai_admin;
-- Link the app's `all_admin` role to the created role.
GRANT APPLICATION ROLE relationalai.all_admin TO ROLE rai_admin;

-- Create a role for developers who need access to the RAI Python API.
CREATE ROLE rai_developer;
-- Link the app's `rai_user` role to the created role.
GRANT APPLICATION ROLE relationalai.rai_user TO ROLE rai_developer;

/*
Users granted the `rai_developer` role can:
Use the RAI Native App.
Create, use, and delete RAI reasoners.
Create, manage, and delete data streams.
Enable and disable the CDC service.
*/

BEGIN

CREATE OR REPLACE PROCEDURE rai_installation_step()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
def main(session):

    # optional: grant the rai_developer role to yourself
    current_user = session.sql("SELECT CURRENT_USER() AS USERNAME;").collect()[0]["USERNAME"]

    session.sql(f'GRANT ROLE rai_developer TO USER "{current_user}"').collect()

    return "Step completed"
$$;

CALL rai_installation_step();

DROP PROCEDURE rai_installation_step();

RETURN 'Step completed';
END;

/*
Our Simple Start template uses a table called
`RAI_DEMO.SIMPLE_START.CONNECTIONS`. If you want to be able to run that
notebook, either grant permissions to the `rai_developer` role or run the
following SQL to create the table now. You can clean up this database when
you're done with the demo notebook by running `DROP DATABASE RAI_DEMO
CASCADE;`
*/

CREATE DATABASE IF NOT EXISTS RAI_DEMO;
CREATE SCHEMA IF NOT EXISTS RAI_DEMO.SIMPLE_START;

CREATE OR REPLACE TABLE RAI_DEMO.SIMPLE_START.CONNECTIONS (
    STATION_1 INT,
    STATION_2 INT
);

INSERT INTO RAI_DEMO.SIMPLE_START.CONNECTIONS (STATION_1, STATION_2) VALUES
(1, 2),
(1, 3),
(3, 4),
(1, 4),
(4, 5),
(5, 7),
(6, 7),
(6, 8),
(7, 8);

GRANT USAGE ON DATABASE RAI_DEMO TO ROLE rai_developer;
GRANT USAGE ON SCHEMA RAI_DEMO.SIMPLE_START TO ROLE rai_developer;
GRANT SELECT ON TABLE RAI_DEMO.SIMPLE_START.CONNECTIONS TO ROLE rai_developer;
ALTER TABLE RAI_DEMO.SIMPLE_START.CONNECTIONS SET CHANGE_TRACKING = TRUE;

-- optional: give rai_developer more extensive permissions in the RAI_DEMO database
-- this step is necessary for the user to be able to run all the demo notebooks
GRANT CREATE SCHEMA ON DATABASE RAI_DEMO TO ROLE rai_developer;
GRANT CREATE TABLE ON SCHEMA RAI_DEMO.SIMPLE_START TO ROLE rai_developer;
GRANT CREATE TABLE ON FUTURE SCHEMAS IN DATABASE RAI_DEMO TO ROLE rai_developer;
GRANT SELECT ON ALL TABLES IN SCHEMA RAI_DEMO.SIMPLE_START TO ROLE rai_developer;
GRANT SELECT ON FUTURE TABLES IN DATABASE RAI_DEMO TO ROLE rai_developer;

/*
## Step 4 — Setting up Snowflake Notebooks
*/
-- create a database to contain the notebooks
CREATE DATABASE rai_notebooks;

-- create a warehouse to select when creating a notebook
CREATE WAREHOUSE notebooks_wh;

-- create a compute pool to use when creating a notebook
CREATE COMPUTE POOL NOTEBOOK_CPU_XS
  MIN_NODES = 1
  MAX_NODES = 15
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_RESUME = true
  AUTO_SUSPEND_SECS = 1800
  COMMENT = "Pool for Snowflake Notebooks on Container Runtime";

-- grant the necessary permissions to the rai_developer role
GRANT USAGE ON DATABASE rai_notebooks TO ROLE rai_developer;
GRANT USAGE ON SCHEMA rai_notebooks.public TO ROLE rai_developer;
GRANT CREATE NOTEBOOK ON SCHEMA rai_notebooks.public TO ROLE rai_developer;
GRANT USAGE ON WAREHOUSE notebooks_wh TO ROLE rai_developer;
GRANT USAGE ON COMPUTE POOL NOTEBOOK_CPU_XS TO ROLE rai_developer;
GRANT CREATE SERVICE ON SCHEMA rai_notebooks.public TO ROLE rai_developer;

/*
install Python packages from PyPI in your
notebooks, run the code below to set up an External Access Integration:
*/
-- grant the necessary permissions to the rai_developer role
CREATE OR REPLACE NETWORK RULE pypi_network_rule
MODE = EGRESS
TYPE = HOST_PORT
VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org',  'files.pythonhosted.org');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION pypi_access_integration
ALLOWED_NETWORK_RULES = (pypi_network_rule)
ENABLED = true;

GRANT USAGE ON INTEGRATION pypi_access_integration TO ROLE rai_developer;

/*
### Warehouse Notebooks
*/

/*
The RelationalAI Python library requires an External Access Integration to
work on notebooks that run on a warehouse. This integration allows the app
to pass query results back to the notebook. Run the following code to set
up the integration:
*/

BEGIN

CREATE OR REPLACE PROCEDURE rai_installation_step()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
def main(session):

    system_allowlist = session.sql("""
    SELECT value:host AS URL
    FROM TABLE(FLATTEN(input=>parse_json(SYSTEM$ALLOWLIST())))
    WHERE value:type = 'STAGE'
    """).collect()

    if system_allowlist:
        urls = ", ".join(row.URL.replace('"', "'") for row in system_allowlist)
        egress_rule_commands = [
            f"""
            CREATE OR REPLACE NETWORK RULE S3_RAI_INTERNAL_BUCKET_EGRESS
            MODE = EGRESS
            TYPE = HOST_PORT
            VALUE_LIST = ({urls});
            """,
            """
            CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION S3_RAI_INTERNAL_BUCKET_EGRESS_INTEGRATION
            ALLOWED_NETWORK_RULES = (S3_RAI_INTERNAL_BUCKET_EGRESS)
            ENABLED = true;
            """,
            """
            GRANT USAGE ON INTEGRATION S3_RAI_INTERNAL_BUCKET_EGRESS_INTEGRATION TO ROLE rai_developer;
            """
        ]

        for command in egress_rule_commands:
            session.sql(command).collect()

        print("Network rule set up successfully.")

    return "Step completed"
$$;

CALL rai_installation_step();

DROP PROCEDURE rai_installation_step();

RETURN 'Step completed';
END;

/*
## Step 5 - Set Up Direct Access
*/
/*
> Note: Connections via Direct Access are not supported by Snowflake
Notebooks at this time.
*/
/*
/*
To create an OAuth security integration, execute the following SQL:
*/

-- Create a public OAuth client for Direct Access.
CREATE SECURITY INTEGRATION RAI_SECURITY_INTEGRATION
  TYPE = OAUTH
  ENABLED = TRUE
  OAUTH_CLIENT = CUSTOM
  OAUTH_CLIENT_TYPE = 'PUBLIC'  -- or 'CONFIDENTIAL' if needed
  OAUTH_ALLOW_NON_TLS_REDIRECT_URI = TRUE
  OAUTH_REDIRECT_URI = 'http://localhost:8001/snowflake/oauth-redirect'
  OAUTH_ISSUE_REFRESH_TOKENS = TRUE
  OAUTH_REFRESH_TOKEN_VALIDITY = 86400;  -- Time in seconds

/*
Note that the redirect URI can be any localhost URI, but the port must be
open on the user's machine.
*/
-- Inspect the created integration. Change the integration name if you used
-- a different one in step 1.
DESC SECURITY INTEGRATION RAI_SECURITY_INTEGRATION;

/*
## Step 6 - Enable Warm Reasoners (Optional)
*/
/*
## Congratulations! Your RelationalAI app is now ready to use.
*/


/*
If you prefer to schedule upgrades for a different day and time, use the
`schedule_upgrade()` procedure:
*/

BEGIN

CREATE OR REPLACE PROCEDURE rai_installation_step()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
def main(session):

    skip_appendix = True

    if not skip_appendix:
        # Schedule upgrades for Wednesdays at 15:00 UTC. Times are in 24-hour format.
        session.sql("CALL relationalai.app.schedule_upgrade('WEDNESDAY', '15:00');").collect()

    return "Step completed"
$$;

CALL rai_installation_step();

DROP PROCEDURE rai_installation_step();

RETURN 'Step completed';
END;
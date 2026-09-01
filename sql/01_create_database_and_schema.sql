-- ============================================================
-- 01_create_database_and_schema.sql
-- Purpose: Create the database and schema where Netflix data lives
-- Teaching Note: In Snowflake, databases and schemas are like folders
--   - Database = top-level container (like a hard drive)
--   - Schema = sub-container within database (like a folder)
--   - Tables = the actual data files (like spreadsheets in a folder)
--
-- BEFORE RUNNING: Make sure you have the right role and warehouse
--   Use: USE ROLE SYSADMIN;  (to create databases)
--   Or:  USE ROLE SECURITYADMIN;  (to grant access)
-- ============================================================

-- ---- Step 1: Switch to SYSADMIN role ----
-- WHY: Only SYSADMIN can create databases. This is a Snowflake security rule.
-- Teaching: Roles control WHO can do WHAT. SYSADMIN has the highest privileges.
USE ROLE SYSADMIN;

-- ---- Step 2: Create the Database ----
-- WHY: This is the top-level container for all Netflix analytics data
-- Teaching: IF NOT EXISTS prevents errors if you run this script twice
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB
    COMMENT = 'Main analytics database for Netflix and streaming data';

-- ---- Step 3: Create the Schema ----
-- WHY: Schemas organize tables within a database
-- Teaching: Think of this as creating a "Netflix" folder inside the database
USE DATABASE ANALYTICS_DB;

CREATE SCHEMA IF NOT EXISTS NETFLIX_SCHEMA
    COMMENT = 'Schema for Netflix weekly viewership data and related tables';

-- ---- Step 4: Set Active Schema ----
-- WHY: So all subsequent commands in this session target the right schema
-- Teaching: This is like cd-ing into a folder in the terminal
USE SCHEMA NETFLIX_SCHEMA;

-- ---- Step 5: Create a Warehouse (compute) ----
-- WHY: You need a warehouse to run queries. It's like the "engine" that processes SQL.
-- Teaching: XS (extra small) is fine for development. Use M/L in production.
CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
    WAREHOUSE_SIZE = 'X-SMALL'          -- Smallest size (cheapest for dev)
    AUTO_SUSPEND = 60                    -- Shut down after 60 seconds of inactivity
    AUTO_RESUME = TRUE                   -- Automatically start when a query runs
    COMMENT = 'Warehouse for Netflix data analytics queries';

-- ---- Step 6: Verify Creation ----
-- WHY: Always verify your objects were created correctly
-- Teaching: This is a "sanity check" — like looking both ways before crossing
SHOW DATABASES LIKE 'ANALYTICS_DB';
SHOW SCHEMAS IN DATABASE ANALYTICS_DB LIKE 'NETFLIX_SCHEMA';
SHOW WAREhouses LIKE 'ANALYTICS_WH';

-- ---- Expected Output ----
-- You should see:
--   ANALYTICS_DB    in databases
--   NETFLIX_SCHEMA  in schemas
--   ANALYTICS_WH    in warehouses
-- ============================================================
-- END OF SCRIPT — Database and schema are ready!
-- Next: Run 02_create_tables.sql to create the data tables
-- ============================================================

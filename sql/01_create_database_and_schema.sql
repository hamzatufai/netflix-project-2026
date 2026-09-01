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

-- Step 1: Switch to SYSADMIN role
-- Only SYSADMIN can create databases. Roles control WHO can do WHAT.
USE ROLE SYSADMIN;

-- Step 2: Create the Database
-- IF NOT EXISTS prevents errors if you run this script twice.
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB
    COMMENT = 'Main analytics database for Netflix and streaming data';

-- Step 3: Create the Schema
-- Think of this as creating a "Netflix" folder inside the database.
USE DATABASE ANALYTICS_DB;

CREATE SCHEMA IF NOT EXISTS NETFLIX_SCHEMA
    COMMENT = 'Schema for Netflix weekly viewership data and related tables';

-- Step 4: Set Active Schema
-- Like cd-ing into a folder in the terminal.
USE SCHEMA NETFLIX_SCHEMA;

-- Step 5: Create a Warehouse (compute)
-- XS (extra small) is fine for development. Use M/L in production.
CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for Netflix data analytics queries';

-- Step 6: Verify Creation
-- Always verify your objects were created correctly (sanity check).
SHOW DATABASES LIKE 'ANALYTICS_DB';
SHOW SCHEMAS IN DATABASE ANALYTICS_DB LIKE 'NETFLIX_SCHEMA';
SHOW WAREhouses LIKE 'ANALYTICS_WH';

-- Expected Output:
--   ANALYTICS_DB    in databases
--   NETFLIX_SCHEMA  in schemas
--   ANALYTICS_WH    in warehouses
-- ============================================================
-- END OF SCRIPT — Database and schema are ready!
-- Next: Run 02_create_tables.sql to create the data tables
-- ============================================================

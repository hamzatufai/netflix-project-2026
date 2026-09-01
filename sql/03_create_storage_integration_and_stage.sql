-- ============================================================
-- 03_create_storage_integration_and_stage.sql
-- Purpose: Connect Snowflake to your S3 bucket via Storage Integration
-- Teaching Note: This is the BRIDGE between AWS and Snowflake.
--
--   How it works (3 steps):
--     1. Storage Integration = Tells Snowflake "trust this AWS role"
--     2. External Stage = Points to the S3 folder where CSVs live
--     3. (Later) COPY INTO = Actually loads data from stage into table
--
-- BEFORE RUNNING:
--   1. Complete Step 1 in README.md (terraform apply)
--   2. Copy the IAM_ROLE_ARN from terraform outputs
--   3. Replace YOUR_IAM_ROLE_ARN below with that value
--   4. You need the SECURITYADMIN or ACCOUNTADMIN role
-- ============================================================

-- ---- Set Context ----
USE ROLE SECURITYADMIN;
-- WHY: Creating integrations requires SECURITYADMIN or ACCOUNTADMIN role
-- Teaching: Different operations need different roles:
--   SYSADMIN    → create databases, tables, warehouses
--   SECURITYADMIN → create integrations, manage access
--   ACCOUNTADMIN → everything (use sparingly)

USE DATABASE ANALYTICS_DB;
USE SCHEMA NETFLIX_SCHEMA;

-- ============================================================
-- STEP 1: CREATE STORAGE INTEGRATION
-- ============================================================
-- WHY: This tells Snowflake which AWS IAM role to trust
-- Teaching: Think of this as a "handshake" between Snowflake and AWS.
--   Snowflake stores the IAM role ARN and an external ID.
--   When Snowflake accesses S3, AWS verifies this trust relationship.

CREATE OR REPLACE STORAGE INTEGRATION netflix_s3_integration
    TYPE = EXTERNAL_STAGE
    -- TYPE: EXTERNAL_STAGE means "data lives outside Snowflake" (in S3)

    ENABLED = TRUE
    -- WHY: Must be TRUE for the integration to work

    STORAGE_PROVIDER = S3
    -- WHY: We're using AWS S3 (other options: AZURE, GCS)

    STORAGE_AWS_ROLE_ARN = 'YOUR_IAM_ROLE_ARN'
    -- !! REPLACE THIS !!
    -- Get this from: terraform output snowflake_role_arn
    -- Example: 'arn:aws:iam::123456789012:role/snowflake-s3-reader-dev'

    STORAGE_AWS_EXTERNAL_ID = 'NETFLIX_PIPELINE_dev'
    -- WHY: This matches the Condition in the IAM role's trust policy
    -- Teaching: External IDs are a security mechanism to prevent
    --   "confused deputy" attacks (where a bad actor tricks AWS into
    --   assuming a role they shouldn't have access to)

    COMMENT = 'Integration between Snowflake and S3 for Netflix data pipeline';

-- ---- GRANT ACCESS ----
-- WHY: The integration is created, but USAGE needs to be granted
-- Teaching: In Snowflake, creating an object ≠ being able to use it.
--   You must explicitly GRANT access to roles that need it.
GRANT USAGE ON INTEGRATION netflix_s3_integration TO ROLE SYSADMIN;

-- ============================================================
-- STEP 2: CREATE EXTERNAL STAGE
-- ============================================================
-- WHY: The stage is a "pointer" to the S3 folder where CSV files live
-- Teaching: Think of a stage as a "loading dock" — data waits here
--   before being pulled into tables via COPY INTO.

CREATE OR REPLACE STAGE netflix_s3_stage
    URL = 's3://netflix_2026/weekly-data/'
    -- !! REPLACE BUCKET NAME if different !!
    -- Get this from: terraform output bucket_name
    -- The URL format is: s3://<bucket-name>/<folder-path>/

    STORAGE_INTEGRATION = netflix_s3_integration
    -- WHY: Links this stage to the integration we just created
    -- Without this, Snowflake wouldn't know which IAM role to use

    FILE_FORMAT = (
        TYPE = 'CSV'
        -- WHY: Our Netflix data files are CSV format

        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        -- WHY: Some fields contain commas (like show titles with quotes)
        -- This tells Snowflake to treat quoted strings as single fields

        SKIP_HEADER = 1
        -- WHY: The first row of our CSV is column headers, not data
        -- This skips the header row during loading

        NULL_IF = ('', 'N/A', 'null', 'NULL')
        -- WHY: The CSV uses "N/A" for null values (like season_title for films)
        -- This converts them to actual SQL NULLs

        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        -- WHY: If a row has extra columns, don't fail — just ignore extras
        -- Teaching: Useful during development when CSV format might change

        TRIM_SPACE = TRUE
        -- WHY: Remove leading/trailing spaces from field values
        -- Prevents issues like " Netflix" vs "Netflix"

        EMPTY_FIELD_AS_NULL = TRUE
        -- WHY: Empty strings become NULL instead of empty strings
        -- Better for data analysis (NULL means "no value")
    )
    COMMENT = 'External stage pointing to Netflix CSV files in S3';

-- ---- GRANT ACCESS ----
GRANT USAGE ON STAGE netflix_s3_stage TO ROLE SYSADMIN;

-- ============================================================
-- STEP 3: VERIFY THE CONNECTION
-- ============================================================
-- WHY: Test that Snowflake can actually see files in your S3 bucket
-- Teaching: Always verify before loading data. This saves debugging time.

-- List files in the stage (should show your CSV files)
LIST @netflix_s3_stage;
-- Expected output: A list of CSV files with sizes and timestamps
-- Example:
--   weekly-data/2026-05-25_global_weekly.csv  45231  ...
--   weekly-data/2026-05-18_global_weekly.csv  44102  ...

-- ============================================================
-- STEP 4: TEST DATA PREVIEW (Optional but recommended)
-- ============================================================
-- WHY: Preview the CSV data BEFORE loading to catch format issues
-- Teaching: This is like "looking before you leap"

-- Preview first 5 rows from the CSV
SELECT *
FROM @netflix_s3_stage
LIMIT 5;
-- Expected output: 5 rows of Netflix data with all columns

-- Preview with column mapping (verify columns align)
SELECT
    $1::DATE        AS week,
    $2::VARCHAR     AS category,
    $3::INTEGER     AS weekly_rank,
    $4::VARCHAR     AS show_title,
    $5::VARCHAR     AS season_title,
    $6::BIGINT      AS weekly_hours_viewed,
    $7::DECIMAL     AS runtime,
    $8::BIGINT      AS weekly_views,
    $9::INTEGER     AS cumulative_weeks_in_top_10
FROM @netflix_s3_stage
LIMIT 10;

-- ============================================================
-- END OF SCRIPT — Storage integration and stage are ready!
-- Next: Run 04_load_data.sql to actually load the CSV data
-- ============================================================

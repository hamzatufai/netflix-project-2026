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
-- Different operations need different roles:
--   SYSADMIN      → create databases, tables, warehouses
--   SECURITYADMIN → create integrations, manage access
--   ACCOUNTADMIN  → everything (use sparingly)
USE ROLE SECURITYADMIN;
USE DATABASE ANALYTICS_DB;
USE SCHEMA NETFLIX_SCHEMA;

-- ============================================================
-- STEP 1: CREATE STORAGE INTEGRATION
-- ============================================================
-- This tells Snowflake which AWS IAM role to trust. Think of it as
-- a "handshake" between Snowflake and AWS. Snowflake stores the IAM
-- role ARN and an external ID. When Snowflake accesses S3, AWS
-- verifies this trust relationship.
-- ============================================================

CREATE OR REPLACE STORAGE INTEGRATION netflix_s3_integration
    TYPE = EXTERNAL_STAGE
    ENABLED = TRUE
    STORAGE_PROVIDER = S3
    STORAGE_AWS_ROLE_ARN = 'YOUR_IAM_ROLE_ARN'
    -- !! REPLACE THIS !!
    -- Get from: terraform output snowflake_role_arn
    -- Example: 'arn:aws:iam::123456789012:role/snowflake-s3-reader-dev'
    STORAGE_AWS_EXTERNAL_ID = 'NETFLIX_PIPELINE_dev'
    -- Matches the Condition in the IAM role's trust policy.
    -- External IDs prevent "confused deputy" attacks.
    COMMENT = 'Integration between Snowflake and S3 for Netflix data pipeline';

-- Grant USAGE so SYSADMIN can actually use this integration.
-- In Snowflake, creating an object ≠ being able to use it.
GRANT USAGE ON INTEGRATION netflix_s3_integration TO ROLE SYSADMIN;

-- ============================================================
-- STEP 2: CREATE EXTERNAL STAGE
-- ============================================================
-- The stage is a "pointer" to the S3 folder where CSV files live.
-- Think of a stage as a "loading dock" — data waits here before
-- being pulled into tables via COPY INTO.
-- ============================================================

CREATE OR REPLACE STAGE netflix_s3_stage
    URL = 's3://netflix_2026/weekly-data/'
    -- !! REPLACE BUCKET NAME if different !!
    -- Get from: terraform output bucket_name
    STORAGE_INTEGRATION = netflix_s3_integration
    FILE_FORMAT = (
        TYPE = 'CSV'
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        SKIP_HEADER = 1
        NULL_IF = ('', 'N/A', 'null', 'NULL')
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        TRIM_SPACE = TRUE
        EMPTY_FIELD_AS_NULL = TRUE
    )
    COMMENT = 'External stage pointing to Netflix CSV files in S3';

-- File format reference:
--   FIELD_OPTIONALLY_ENCLOSED_BY = '"'  — Handle commas inside quoted fields
--   SKIP_HEADER = 1                     — Skip CSV column headers
--   NULL_IF = (...)                    — Convert 'N/A', '' etc. to SQL NULL
--   ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE — Don't fail on extra columns
--   TRIM_SPACE = TRUE                  — Remove leading/trailing spaces
--   EMPTY_FIELD_AS_NULL = TRUE         — Empty strings become NULL

GRANT USAGE ON STAGE netflix_s3_stage TO ROLE SYSADMIN;

-- ============================================================
-- STEP 3: VERIFY THE CONNECTION
-- ============================================================
-- Always verify before loading data. This saves debugging time.
-- ============================================================

LIST @netflix_s3_stage;
-- Expected: A list of CSV files with sizes and timestamps

-- ============================================================
-- STEP 4: TEST DATA PREVIEW (Optional but recommended)
-- ============================================================
-- Preview the CSV data BEFORE loading to catch format issues.
-- ============================================================

SELECT * FROM @netflix_s3_stage LIMIT 5;

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

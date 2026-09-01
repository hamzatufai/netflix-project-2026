-- ============================================================
-- 04_load_data.sql
-- Purpose: Load Netflix CSV data from S3 into Snowflake tables
-- Teaching Note: COPY INTO is Snowflake's bulk loading command.
--   It reads files from the stage (S3) and inserts them into tables.
--
--   Two methods shown:
--     1. COPY INTO (recommended) — bulk load, efficient, trackable
--     2. INSERT with @stage — more control, slower for large files
--
-- BEFORE RUNNING: Complete steps 01, 02, and 03 first
-- ============================================================

-- ---- Set Context ----
USE ROLE SYSADMIN;
USE DATABASE ANALYTICS_DB;
USE SCHEMA NETFLIX_SCHEMA;
USE WAREHOUSE ANALYTICS_WH;

-- ============================================================
-- METHOD 1: COPY INTO (Recommended for Production)
-- ============================================================
-- COPY INTO is Snowflake's primary bulk loading mechanism.
-- It's parallelized (reads multiple file parts simultaneously),
-- tracks which files have been loaded (prevents duplicates),
-- and reports errors per row for debugging.
-- ============================================================

-- Step 1: Load into RAW table.
-- Always load raw data first, then transform to clean table.
COPY INTO RAW_WEEKLY_VIEWS (
    week,
    category,
    weekly_rank,
    show_title,
    season_title,
    weekly_hours_viewed,
    runtime,
    weekly_views,
    cumulative_weeks_in_top_10
)
FROM (
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
)
-- ON_ERROR options: ABORT (stop on first error), CONTINUE (skip bad rows), SKIP_FILE
ON_ERROR = 'CONTINUE'
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('', 'N/A', 'null', 'NULL')
    TRIM_SPACE = TRUE
    EMPTY_FIELD_AS_NULL = TRUE
)
-- FORCE = TRUE forces a full reload. Remove for incremental loads (only load new files).
FORCE = FALSE
;

-- ============================================================
-- Step 2: Load into CLEAN table (Transform from RAW)
-- ============================================================
-- Now that raw data is loaded, transform and insert into production table.
-- This is the "T" in ELT (Extract, Load, Transform).
-- ============================================================

INSERT INTO NETFLIX_WEEKLY_VIEWS (
    week,
    category,
    weekly_rank,
    show_title,
    season_title,
    weekly_hours_viewed,
    runtime,
    weekly_views,
    cumulative_weeks_in_top_10,
    _transformed_at
)
SELECT
    week,
    category,
    weekly_rank,
    show_title,
    -- Convert 'N/A' / 'null' to NULL for cleaner data
    CASE
        WHEN season_title = 'N/A' THEN NULL
        WHEN season_title = 'null' THEN NULL
        ELSE TRIM(season_title)
    END AS season_title,
    weekly_hours_viewed,
    runtime,
    weekly_views,
    cumulative_weeks_in_top_10,
    CURRENT_TIMESTAMP() AS _transformed_at
FROM RAW_WEEKLY_VIEWS
-- Deduplication: only insert rows not already in the clean table
WHERE (week, category, weekly_rank) NOT IN (
    SELECT week, category, weekly_rank
    FROM NETFLIX_WEEKLY_VIEWS
)
AND show_title IS NOT NULL
;

-- ============================================================
-- Step 3: Log the data load
-- ============================================================
-- Production data pipelines ALWAYS have logging for audit purposes.
-- ============================================================

INSERT INTO DATA_LOAD_LOG (
    source_file,
    rows_loaded,
    load_status,
    load_duration_seconds
)
SELECT
    's3://netflix_2026/weekly-data/*.csv' AS source_file,
    COUNT(*)                              AS rows_loaded,
    'SUCCESS'                             AS load_status,
    0                                     AS load_duration_seconds
FROM RAW_WEEKLY_VIEWS
WHERE DATE(_loaded_at) = CURRENT_DATE()
;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================
-- Run these after loading to check your work.
-- ============================================================

-- Row counts: RAW and CLEAN should be similar (~450 rows each)
SELECT
    'RAW table' AS table_name,
    COUNT(*) AS row_count
FROM RAW_WEEKLY_VIEWS
UNION ALL
SELECT
    'CLEAN table' AS table_name,
    COUNT(*) AS row_count
FROM NETFLIX_WEEKLY_VIEWS
UNION ALL
SELECT
    'Load log' AS table_name,
    COUNT(*) AS row_count
FROM DATA_LOAD_LOG;

-- Data distribution by category (expect 4 categories, 2025-11 to 2026-05)
SELECT
    category,
    COUNT(*) AS total_rows,
    MIN(week) AS earliest_week,
    MAX(week) AS latest_week
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY category
ORDER BY category;

-- Sample data for most recent week (expect top 10 for each of 4 categories)
SELECT
    week,
    category,
    weekly_rank,
    show_title,
    weekly_hours_viewed,
    weekly_views
FROM NETFLIX_WEEKLY_VIEWS
WHERE week = '2026-05-17'
ORDER BY category, weekly_rank
LIMIT 20;

-- Load history
SELECT * FROM DATA_LOAD_LOG
ORDER BY load_timestamp DESC
LIMIT 5;

-- ============================================================
-- END OF SCRIPT — Data is loaded!
-- Next: Run 05_analysis_queries.sql to start analyzing the data
-- ============================================================

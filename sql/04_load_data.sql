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
-- WHY: COPY INTO is Snowflake's primary bulk loading mechanism
-- Teaching: Think of it as "COPY data FROM stage INTO table"
--   - It's parallelized (reads multiple file parts simultaneously)
--   - It tracks which files have been loaded (prevents duplicates)
--   - It reports errors per row for debugging

-- ---- Step 1: Load into RAW table ----
-- WHY: Always load raw data first, then transform to clean table
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
        -- ---- Column Mapping ----
        -- WHY: Explicit mapping prevents column order issues
        -- Teaching: $1, $2, etc. refer to CSV columns in order
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
-- ---- Error Handling Options ----
-- WHY: Control what happens when bad data is encountered
ON_ERROR = 'CONTINUE'
-- Options:
--   ABORT      = Stop immediately on first error (safest)
--   CONTINUE   = Skip bad rows, continue loading (good for dev)
--   SKIP_FILE  = Skip entire file if any row has errors

-- ---- File Selection ----
-- WHY: Only load files matching this pattern
-- Teaching: Use this to load specific weeks without re-loading everything
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('', 'N/A', 'null', 'NULL')
    TRIM_SPACE = TRUE
    EMPTY_FIELD_AS_NULL = TRUE
)

-- ---- Load Tracking ----
-- WHY: Forces a full reload — removes the "already loaded" marker
-- Teaching: Remove this line for incremental loads (only load new files)
FORCE = FALSE
-- Set to TRUE only when you want to reload all files

-- ---- Result ----
-- This will show: rows loaded, rows parsed, errors, etc.
;

-- ============================================================
-- Step 2: Load into CLEAN table (Transform from RAW)
-- ============================================================
-- WHY: Now that raw data is loaded, transform and insert into production table
-- Teaching: This is the "T" in ELT (Extract, Load, Transform)

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
    -- ---- Direct mappings (same as raw) ----
    week,
    category,
    weekly_rank,
    show_title,
    -- ---- Transformation: season_title ----
    -- WHY: Convert 'N/A' to NULL for cleaner data
    -- Teaching: NULL means "no value" which is more meaningful than a string
    CASE
        WHEN season_title = 'N/A' THEN NULL
        WHEN season_title = 'null' THEN NULL
        ELSE TRIM(season_title)
    END AS season_title,
    weekly_hours_viewed,
    runtime,
    weekly_views,
    cumulative_weeks_in_top_10,

    -- ---- Timestamp when transformation happened ----
    CURRENT_TIMESTAMP() AS _transformed_at

FROM RAW_WEEKLY_VIEWS
-- ---- Deduplication ----
-- WHY: Prevent duplicate rows if data is loaded multiple times
-- Teaching: This pattern ensures each (week, category, rank) combo is unique
WHERE (week, category, weekly_rank) NOT IN (
    SELECT week, category, weekly_rank
    FROM NETFLIX_WEEKLY_VIEWS
)
AND show_title IS NOT NULL   -- Skip any rows with missing titles
;

-- ============================================================
-- Step 3: Log the data load
-- WHY: Always log what you did for audit purposes
-- Teaching: Production data pipelines ALWAYS have logging

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
    -- NOTE: In production, you'd calculate actual duration
FROM RAW_WEEKLY_VIEWS
WHERE DATE(_loaded_at) = CURRENT_DATE()
;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================
-- WHY: Always verify data loaded correctly
-- Teaching: Run these after loading to check your work

-- ---- Check 1: Row counts ----
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

-- Expected: RAW and CLEAN should have similar row counts
-- Example: ~450 rows each (100 weeks × ~4-5 categories × top 10)

-- ---- Check 2: Data distribution by category ----
SELECT
    category,
    COUNT(*) AS total_rows,
    MIN(week) AS earliest_week,
    MAX(week) AS latest_week
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY category
ORDER BY category;

-- Expected: 4 categories, each with data from 2025-11 to 2026-05

-- ---- Check 3: Sample data ----
SELECT
    week,
    category,
    weekly_rank,
    show_title,
    weekly_hours_viewed,
    weekly_views
FROM NETFLIX_WEEKLY_VIEWS
WHERE week = '2026-05-17'   -- Most recent week
ORDER BY category, weekly_rank
LIMIT 20;

-- Expected: Top 10 for each of the 4 categories

-- ---- Check 4: Load history ----
SELECT * FROM DATA_LOAD_LOG
ORDER BY load_timestamp DESC
LIMIT 5;

-- ============================================================
-- END OF SCRIPT — Data is loaded!
-- Next: Run 05_analysis_queries.sql to start analyzing the data
-- ============================================================

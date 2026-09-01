-- ============================================================
-- 02_create_tables.sql
-- Purpose: Create tables that store Netflix weekly viewership data
-- Teaching Note: Table design is crucial. Good design = fast queries, easy analysis.
--
--   This file creates:
--     1. RAW table (staging) — where CSV data lands first
--     2. CLEAN table (production) — cleaned and validated data
--     3. DIMENSION tables — reference data for categories, etc.
--
-- BEFORE RUNNING: Make sure you've run 01_create_database_and_schema.sql first
-- ============================================================

-- ---- Set Context ----
USE ROLE SYSADMIN;
USE DATABASE ANALYTICS_DB;
USE SCHEMA NETFLIX_SCHEMA;
USE WAREHOUSE ANALYTICS_WH;

-- ============================================================
-- TABLE 1: RAW WEEKLY VIEWS (Staging Table)
-- ============================================================
-- WHY: This table receives data DIRECTLY from CSV files via COPY INTO
-- Teaching: Raw tables are "landing zones" — they hold data exactly as
--   it comes from the source. No transformations yet.
--   This makes debugging easier: if something goes wrong, you can
--   compare the raw table to the original CSV.

CREATE OR REPLACE TABLE RAW_WEEKLY_VIEWS (
    -- ---- Column: week ----
    -- WHY: The week the data was published (date format: YYYY-MM-DD)
    -- TYPE: DATE — Snowflake automatically parses '2026-05-17' as a date
    week                    DATE            NOT NULL,

    -- ---- Column: category ----
    -- WHY: Content type and language (e.g., "Films (English)", "TV (Non-English)")
    -- TYPE: VARCHAR(50) — Text up to 50 characters
    category                VARCHAR(50)     NOT NULL,

    -- ---- Column: weekly_rank ----
    -- WHY: Position in the top 10 list (1 = most viewed)
    -- TYPE: INTEGER — Whole numbers only (1, 2, 3, ... 10)
    weekly_rank             INTEGER         NOT NULL,

    -- ---- Column: show_title ----
    -- WHY: Name of the movie or TV show
    -- TYPE: VARCHAR(500) — Some titles are long (special characters, accents)
    show_title              VARCHAR(500)    NOT NULL,

    -- ---- Column: season_title ----
    -- WHY: Season info for TV shows (null for films, which show "N/A" in CSV)
    -- Teaching: Using NULL instead of 'N/A' is better database practice
    season_title            VARCHAR(500)    NULL,

    -- ---- Column: weekly_hours_viewed ----
    -- WHY: Total hours watched across all users that week
    -- TYPE: BIGINT — Numbers can be very large (millions of hours)
    weekly_hours_viewed     BIGINT          NOT NULL,

    -- ---- Column: runtime ----
    -- WHY: Average runtime in hours (e.g., 1.7 = 1 hour 42 minutes)
    -- TYPE: DECIMAL(10,4) — 10 digits total, 4 after decimal point
    runtime                 DECIMAL(10,4)   NOT NULL,

    -- ---- Column: weekly_views ----
    -- WHY: Estimated number of complete viewings that week
    -- TYPE: BIGINT — Can be millions
    weekly_views            BIGINT          NOT NULL,

    -- ---- Column: cumulative_weeks_in_top_10 ----
    -- WHY: How many weeks the title has been in the top 10 (popularity indicator)
    -- TYPE: INTEGER — Usually 1-50
    cumulative_weeks_in_top_10  INTEGER     NOT NULL,

    -- ---- Metadata Columns (NOT in CSV — added automatically) ----
    -- WHY: Track when data was loaded and by what process
    -- Teaching: Always add metadata columns. They help with debugging and auditing.
    _loaded_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _load_source            VARCHAR(100)    DEFAULT 'S3_CSV'
);

-- ---- Add Comment to Table ----
-- WHY: Documentation lives WITH the table, not just in a wiki
COMMENT ON TABLE RAW_WEEKLY_VIEWS IS
    'Raw Netflix weekly viewership data loaded directly from S3 CSV files. Do not modify — this is the source of truth.';

-- ============================================================
-- TABLE 2: NETFLIX_WEEKLY_VIEWS (Clean / Production Table)
-- ============================================================
-- WHY: This table has cleaned, validated data for analysis
-- Teaching: Separating raw from clean data follows the "ELT" pattern:
--   E = Extract (CSV → S3 → RAW table)
--   L = Load (RAW → CLEAN with transformations)
--   T = Transform (clean, validate, enrich)
--   You ALWAYS keep the raw data in case you need to reprocess it.

CREATE OR REPLACE TABLE NETFLIX_WEEKLY_VIEWS (
    -- ---- Core columns (same as raw, but with better types) ----
    view_id                 INTEGER         AUTOINCREMENT  PRIMARY KEY,
    -- WHY: Auto-generated unique ID for each row. Useful for joins and debugging.

    week                    DATE            NOT NULL,
    category                VARCHAR(50)     NOT NULL,
    weekly_rank             INTEGER         NOT NULL,
    show_title              VARCHAR(500)    NOT NULL,
    season_title            VARCHAR(500)    NULL,
    weekly_hours_viewed     BIGINT          NOT NULL,
    runtime                 DECIMAL(10,4)   NOT NULL,
    weekly_views            BIGINT          NOT NULL,
    cumulative_weeks_in_top_10  INTEGER     NOT NULL,

    -- ---- Derived Columns (calculated from raw data) ----
    -- WHY: Pre-calculate common metrics so analysts don't have to compute them
    content_type            VARCHAR(20)     GENERATED ALWAYS AS (
        -- Extract "Films" or "TV" from category string
        CASE
            WHEN category LIKE 'Films%' THEN 'Films'
            WHEN category LIKE 'TV%'    THEN 'TV'
            ELSE 'Unknown'
        END
    ) STORED,

    language_type           VARCHAR(20)     GENERATED ALWAYS AS (
        -- Extract "English" or "Non-English" from category string
        CASE
            WHEN category LIKE '%English%' AND category NOT LIKE '%Non-English%' THEN 'English'
            WHEN category LIKE '%Non-English%' THEN 'Non-English'
            ELSE 'Unknown'
        END
    ) STORED,

    -- ---- Metadata ----
    _loaded_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _transformed_at         TIMESTAMP_NTZ   NULL,
    _load_source            VARCHAR(100)    DEFAULT 'RAW_WEEKLY_VIEWS'
);

-- ---- Add Comments ----
COMMENT ON TABLE NETFLIX_WEEKLY_VIEWS IS
    'Clean Netflix weekly viewership data with derived columns. Source: RAW_WEEKLY_VIEWS.';

-- ============================================================
-- TABLE 3: DATA_LOAD_LOG (Audit / Tracking)
-- ============================================================
-- WHY: Track every data load — when, how much, success/failure
-- Teaching: Audit tables are essential for production data pipelines.
--   They answer: "When was the data last loaded?" and "Did it fail?"

CREATE OR REPLACE TABLE DATA_LOAD_LOG (
    load_id                 INTEGER         AUTOINCREMENT  PRIMARY KEY,
    load_timestamp          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    source_file             VARCHAR(500)    NOT NULL,
    rows_loaded             INTEGER         DEFAULT 0,
    rows_rejected           INTEGER         DEFAULT 0,
    load_status             VARCHAR(20)     DEFAULT 'IN_PROGRESS',
    -- STATUS values: IN_PROGRESS, SUCCESS, FAILED, PARTIAL
    error_message           VARCHAR(2000)   NULL,
    load_duration_seconds   DECIMAL(10,2)   NULL
);

COMMENT ON TABLE DATA_LOAD_LOG IS
    'Audit log tracking each data load — captures file, row counts, status, and errors.';

-- ============================================================
-- TABLE 4: CATEGORY_DIMENSION (Reference / Lookup Table)
-- ============================================================
-- WHY: Normalize category data — store it once, reference by ID
-- Teaching: Dimension tables follow the "star schema" pattern:
--   - Fact table (NETFLIX_WEEKLY_VIEWS) = the measurements/events
--   - Dimension tables (CATEGORY_DIMENSION) = the descriptive context
--   This makes queries faster and data more consistent.

CREATE OR REPLACE TABLE CATEGORY_DIMENSION (
    category_id             INTEGER         AUTOINCREMENT  PRIMARY KEY,
    category_name           VARCHAR(50)     NOT NULL UNIQUE,
    -- UNIQUE constraint prevents duplicate category names
    content_type            VARCHAR(20)     NOT NULL,
    language_type           VARCHAR(20)     NOT NULL,
    is_active               BOOLEAN         DEFAULT TRUE,
    created_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- ---- Insert known categories ----
-- WHY: Pre-populate with the 4 Netflix categories from the data
-- Teaching: This is called "seeding" a dimension table
INSERT INTO CATEGORY_DIMENSION (category_name, content_type, language_type) VALUES
    ('Films (English)',       'Films', 'English'),
    ('Films (Non-English)',   'Films', 'Non-English'),
    ('TV (English)',          'TV',    'English'),
    ('TV (Non-English)',      'TV',    'Non-English');

-- ============================================================
-- VERIFICATION: Check all tables were created
-- ============================================================
SHOW TABLES IN SCHEMA ANALYTICS_DB.NETFLIX_SCHEMA;

-- Expected output:
--   RAW_WEEKLY_VIEWS
--   NETFLIX_WEEKLY_VIEWS
--   DATA_LOAD_LOG
--   CATEGORY_DIMENSION
-- ============================================================
-- END OF SCRIPT — Tables are ready!
-- Next: Run 03_create_storage_integration_and_stage.sql
-- ============================================================

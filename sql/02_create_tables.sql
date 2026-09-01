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
-- This table receives data DIRECTLY from CSV files via COPY INTO.
-- Raw tables are "landing zones" — they hold data exactly as it comes
-- from the source with no transformations. This makes debugging easier:
-- if something goes wrong, compare the raw table to the original CSV.
-- ============================================================

CREATE OR REPLACE TABLE RAW_WEEKLY_VIEWS (
    week                    DATE            NOT NULL,
    category                VARCHAR(50)     NOT NULL,
    weekly_rank             INTEGER         NOT NULL,
    show_title              VARCHAR(500)    NOT NULL,
    season_title            VARCHAR(500)    NULL,
    weekly_hours_viewed     BIGINT          NOT NULL,
    runtime                 DECIMAL(10,4)   NOT NULL,
    weekly_views            BIGINT          NOT NULL,
    cumulative_weeks_in_top_10  INTEGER     NOT NULL,
    _loaded_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _load_source            VARCHAR(100)    DEFAULT 'S3_CSV'
);

-- Column reference:
--   week                    — The week the data was published (YYYY-MM-DD)
--   category                — Content type and language, e.g. "Films (English)"
--   weekly_rank             — Position in the top 10 list (1 = most viewed)
--   show_title              — Name of the movie or TV show
--   season_title            — Season info for TV shows (NULL for films)
--   weekly_hours_viewed     — Total hours watched across all users that week
--   runtime                 — Average runtime in hours (e.g., 1.7 = 1h 42m)
--   weekly_views            — Estimated number of complete viewings that week
--   cumulative_weeks_in_top_10 — How many weeks the title has been in the top 10
--   _loaded_at              — Timestamp when data was loaded (metadata)
--   _load_source            — Origin of the data (metadata)

COMMENT ON TABLE RAW_WEEKLY_VIEWS IS
    'Raw Netflix weekly viewership data loaded directly from S3 CSV files. Do not modify — this is the source of truth.';

-- ============================================================
-- TABLE 2: NETFLIX_WEEKLY_VIEWS (Clean / Production Table)
-- ============================================================
-- Clean, validated data for analysis. Separating raw from clean data
-- follows the "ELT" pattern:
--   E = Extract (CSV → S3 → RAW table)
--   L = Load (RAW → CLEAN with transformations)
--   T = Transform (clean, validate, enrich)
-- You ALWAYS keep the raw data in case you need to reprocess it.
-- ============================================================

CREATE OR REPLACE TABLE NETFLIX_WEEKLY_VIEWS (
    view_id INTEGER AUTOINCREMENT PRIMARY KEY,

    week DATE NOT NULL,

    category VARCHAR(50) NOT NULL,

    weekly_rank INTEGER NOT NULL,

    show_title VARCHAR(500) NOT NULL,

    season_title VARCHAR(500),

    weekly_hours_viewed BIGINT NOT NULL,

    runtime DECIMAL(10,4) NOT NULL,

    weekly_views BIGINT NOT NULL,

    cumulative_weeks_in_top_10 INTEGER NOT NULL,

    -- Derived column: content type
    content_type VARCHAR(20)
        AS (
            CASE
                WHEN category LIKE 'Films%' THEN 'Films'
                WHEN category LIKE 'TV%' THEN 'TV'
                ELSE 'Unknown'
            END
        ),

    -- Derived column: language type
    language_type VARCHAR(20)
        AS (
            CASE
                WHEN category LIKE '%English%'
                     AND category NOT LIKE '%Non-English%'
                    THEN 'English'

                WHEN category LIKE '%Non-English%'
                    THEN 'Non-English'

                ELSE 'Unknown'
            END
        ),

    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    _transformed_at TIMESTAMP_NTZ,

    _load_source VARCHAR(100) DEFAULT 'RAW_WEEKLY_VIEWS'
);

-- Column reference:
--   view_id              — Auto-generated unique ID for each row
--   content_type          — Derived: "Films" or "TV" extracted from category
--   language_type         — Derived: "English" or "Non-English" extracted from category

COMMENT ON TABLE NETFLIX_WEEKLY_VIEWS IS
    'Clean Netflix weekly viewership data with derived columns. Source: RAW_WEEKLY_VIEWS.';

-- ============================================================
-- TABLE 3: DATA_LOAD_LOG (Audit / Tracking)
-- ============================================================
-- Track every data load — when, how much, success/failure.
-- Audit tables are essential for production data pipelines.
-- They answer: "When was the data last loaded?" and "Did it fail?"
-- ============================================================

CREATE OR REPLACE TABLE DATA_LOAD_LOG (
    load_id                 INTEGER         AUTOINCREMENT  PRIMARY KEY,
    load_timestamp          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    source_file             VARCHAR(500)    NOT NULL,
    rows_loaded             INTEGER         DEFAULT 0,
    rows_rejected           INTEGER         DEFAULT 0,
    load_status             VARCHAR(20)     DEFAULT 'IN_PROGRESS',
    error_message           VARCHAR(2000)   NULL,
    load_duration_seconds   DECIMAL(10,2)   NULL
);

-- load_status values: IN_PROGRESS, SUCCESS, FAILED, PARTIAL

COMMENT ON TABLE DATA_LOAD_LOG IS
    'Audit log tracking each data load — captures file, row counts, status, and errors.';

-- ============================================================
-- TABLE 4: CATEGORY_DIMENSION (Reference / Lookup Table)
-- ============================================================
-- Normalize category data — store it once, reference by ID.
-- Dimension tables follow the "star schema" pattern:
--   - Fact table (NETFLIX_WEEKLY_VIEWS) = the measurements/events
--   - Dimension tables (CATEGORY_DIMENSION) = the descriptive context
-- This makes queries faster and data more consistent.
-- ============================================================

CREATE OR REPLACE TABLE CATEGORY_DIMENSION (
    category_id             INTEGER         AUTOINCREMENT  PRIMARY KEY,
    category_name           VARCHAR(50)     NOT NULL UNIQUE,
    content_type            VARCHAR(20)     NOT NULL,
    language_type           VARCHAR(20)     NOT NULL,
    is_active               BOOLEAN         DEFAULT TRUE,
    created_at              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- Pre-populate with the 4 Netflix categories from the data ("seeding").
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

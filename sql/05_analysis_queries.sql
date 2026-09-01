-- ============================================================
-- 05_analysis_queries.sql
-- Purpose: Example analysis queries using the Netflix data
-- Teaching Note: These are real analytics queries you can run
--   immediately after loading data. Each query demonstrates
--   a different SQL technique.
--
-- BEFORE RUNNING: Complete 01-04 and verify data is loaded
-- ============================================================

-- ---- Set Context ----
USE ROLE SYSADMIN;
USE DATABASE ANALYTICS_DB;
USE SCHEMA NETFLIX_SCHEMA;
USE WAREHOUSE ANALYTICS_WH;

-- ============================================================
-- QUERY 1: Top 10 Most Viewed Shows (All Time)
-- ============================================================
-- The most basic "insight" — which content is most popular?
-- Demonstrates GROUP BY, SUM, COUNT(DISTINCT), ORDER BY, LIMIT.
-- ============================================================

SELECT
    show_title,
    category,
    SUM(weekly_hours_viewed) AS total_hours_viewed,
    SUM(weekly_views) AS total_views,
    COUNT(DISTINCT week) AS weeks_in_top_10
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY show_title, category
ORDER BY total_hours_viewed DESC
LIMIT 10;

-- ============================================================
-- QUERY 2: Weekly Trend for a Specific Show
-- ============================================================
-- Track how a show's popularity changes over time.
-- Demonstrates LAG() window function and percentage change calculation.
-- ============================================================

SELECT
    week,
    show_title,
    weekly_rank,
    weekly_hours_viewed,
    weekly_views,
    -- Week-over-week change in hours viewed (uses LAG to look at previous row)
    weekly_hours_viewed - LAG(weekly_hours_viewed) OVER (
        ORDER BY week
    ) AS hours_change_from_previous_week,
    -- Percentage change (NULLIF prevents division by zero)
    ROUND(
        (weekly_hours_viewed - LAG(weekly_hours_viewed) OVER (ORDER BY week))
        * 100.0 / NULLIF(LAG(weekly_hours_viewed) OVER (ORDER BY week), 0),
        1
    ) AS pct_change
FROM NETFLIX_WEEKLY_VIEWS
WHERE show_title = 'Stranger Things'
  AND category = 'TV (English)'
ORDER BY week;

-- ============================================================
-- QUERY 3: Category Performance Summary
-- ============================================================
-- Compare performance across the 4 Netflix categories.
-- Demonstrates GROUP BY with multiple aggregations.
-- ============================================================

SELECT
    category,
    content_type,
    language_type,
    COUNT(DISTINCT show_title) AS unique_titles,
    SUM(weekly_hours_viewed) AS total_hours_viewed,
    ROUND(AVG(weekly_hours_viewed), 0) AS avg_hours_per_entry,
    ROUND(AVG(runtime), 2) AS avg_runtime_hours,
    MAX(cumulative_weeks_in_top_10) AS longest_streak_weeks
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY category, content_type, language_type
ORDER BY total_hours_viewed DESC;

-- ============================================================
-- QUERY 4: Week-over-Week Category Trends
-- ============================================================
-- See how each category's total viewership changes weekly.
-- Demonstrates window functions for running totals and ranking.
-- ============================================================

SELECT
    week,
    category,
    SUM(weekly_hours_viewed) AS weekly_category_hours,
    -- Cumulative sum per category (PARTITION BY resets per category)
    SUM(SUM(weekly_hours_viewed)) OVER (
        PARTITION BY category
        ORDER BY week
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_hours,
    -- Category rank each week
    RANK() OVER (
        PARTITION BY week
        ORDER BY SUM(weekly_hours_viewed) DESC
    ) AS category_rank_that_week
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY week, category
ORDER BY week DESC, category_rank_that_week;

-- ============================================================
-- QUERY 5: Biggest Drops from Rank 1
-- ============================================================
-- Find shows that were #1 but then fell significantly.
-- Demonstrates self-joins via CTEs and ranking.
-- ============================================================

WITH weekly_ranks AS (
    SELECT
        week,
        show_title,
        category,
        weekly_rank,
        weekly_hours_viewed,
        LAG(weekly_rank) OVER (
            PARTITION BY show_title, category
            ORDER BY week
        ) AS previous_week_rank
    FROM NETFLIX_WEEKLY_VIEWS
)
SELECT
    week,
    show_title,
    category,
    previous_week_rank,
    weekly_rank AS current_rank,
    (weekly_rank - previous_week_rank) AS rank_drop,
    CASE
        WHEN weekly_rank - previous_week_rank >= 5 THEN 'DROPPED SIGNIFICANTLY'
        WHEN weekly_rank - previous_week_rank >= 3 THEN 'dropped moderately'
        ELSE 'slight drop'
    END AS severity
FROM weekly_ranks
WHERE previous_week_rank IS NOT NULL
  AND weekly_rank > previous_week_rank
ORDER BY rank_drop DESC, week
LIMIT 15;

-- ============================================================
-- QUERY 6: "Long Tail" Analysis — Shows That Stay Long
-- ============================================================
-- Identify content with long-term staying power vs one-week wonders.
-- Demonstrates CASE WHEN for categorization.
-- ============================================================

SELECT
    show_title,
    category,
    MAX(cumulative_weeks_in_top_10) AS total_weeks_in_top_10,
    SUM(weekly_hours_viewed) AS total_hours_viewed,
    CASE
        WHEN MAX(cumulative_weeks_in_top_10) >= 20 THEN '🟢 MEGA HIT (20+ weeks)'
        WHEN MAX(cumulative_weeks_in_top_10) >= 10 THEN '🟡 STRONG (10-19 weeks)'
        WHEN MAX(cumulative_weeks_in_top_10) >= 5  THEN '🟠 MODERATE (5-9 weeks)'
        ELSE '🔴 ONE-HIT WONDER (<5 weeks)'
    END AS longevity_category
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY show_title, category
ORDER BY total_weeks_in_top_10 DESC, total_hours_viewed DESC
LIMIT 20;

-- ============================================================
-- QUERY 7: Monthly Summary (Aggregate by Month)
-- ============================================================
-- See monthly patterns — when do people watch more?
-- Demonstrates DATE_TRUNC for date grouping.
-- ============================================================

SELECT
    DATE_TRUNC('MONTH', week) AS month,
    COUNT(DISTINCT week) AS weeks_in_month,
    SUM(weekly_hours_viewed) AS total_hours_viewed,
    ROUND(SUM(weekly_hours_viewed) / 1e9, 2) AS total_hours_billions,
    SUM(weekly_views) AS total_views,
    COUNT(DISTINCT show_title) AS unique_titles
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY DATE_TRUNC('MONTH', week)
ORDER BY month;

-- ============================================================
-- END OF SCRIPT — You now have 7 analysis queries!
-- ============================================================
-- Teaching Summary:
--   Query 1: Basic aggregation (GROUP BY, ORDER BY)
--   Query 2: Window functions (LAG for trends)
--   Query 3: Multi-metric aggregation
--   Query 4: Running totals (SUM OVER)
--   Query 5: Self-joins with CTEs (WITH clause)
--   Query 6: CASE WHEN for categorization
--   Query 7: Date truncation for monthly rollups
-- ============================================================

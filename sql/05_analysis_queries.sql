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
-- WHY: The most basic "insight" — which content is most popular?
-- Teaching: Demonstrates ORDER BY and LIMIT

SELECT
    show_title,
    category,
    SUM(weekly_hours_viewed) AS total_hours_viewed,
    -- WHY: SUM adds up hours across all weeks the show appeared
    SUM(weekly_views) AS total_views,
    COUNT(DISTINCT week) AS weeks_in_top_10
    -- WHY: COUNT(DISTINCT) counts unique weeks (not total appearances)
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY show_title, category
ORDER BY total_hours_viewed DESC
LIMIT 10;

-- ============================================================
-- QUERY 2: Weekly Trend for a Specific Show
-- ============================================================
-- WHY: Track how a show's popularity changes over time
-- Teaching: Demonstrates date functions and window-like analysis

SELECT
    week,
    show_title,
    weekly_rank,
    weekly_hours_viewed,
    weekly_views,
    -- ---- Week-over-Week Change ----
    -- WHY: Shows if viewership is growing or declining
    -- Teaching: LAG() is a window function that looks at the previous row
    weekly_hours_viewed - LAG(weekly_hours_viewed) OVER (
        ORDER BY week
    ) AS hours_change_from_previous_week,
    -- Calculate percentage change
    ROUND(
        (weekly_hours_viewed - LAG(weekly_hours_viewed) OVER (ORDER BY week))
        * 100.0 / NULLIF(LAG(weekly_hours_viewed) OVER (ORDER BY week), 0),
        1
    ) AS pct_change
    -- WHY: NULLIF prevents division by zero error
FROM NETFLIX_WEEKLY_VIEWS
WHERE show_title = 'Stranger Things'
  AND category = 'TV (English)'
ORDER BY week;

-- ============================================================
-- QUERY 3: Category Performance Summary
-- ============================================================
-- WHY: Compare performance across the 4 Netflix categories
-- Teaching: Demonstrates GROUP BY with multiple aggregations

SELECT
    category,
    content_type,
    language_type,
    COUNT(DISTINCT show_title) AS unique_titles,
    -- WHY: How many different shows appeared in top 10

    SUM(weekly_hours_viewed) AS total_hours_viewed,
    -- WHY: Total engagement across all shows and weeks

    ROUND(AVG(weekly_hours_viewed), 0) AS avg_hours_per_entry,
    -- WHY: Average engagement per entry (per show per week)

    ROUND(AVG(runtime), 2) AS avg_runtime_hours,
    -- WHY: Average content length in hours

    MAX(cumulative_weeks_in_top_10) AS longest_streak_weeks
    -- WHY: Longest any show stayed in the top 10
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY category, content_type, language_type
ORDER BY total_hours_viewed DESC;

-- ============================================================
-- QUERY 4: Week-over-Week Category Trends
-- ============================================================
-- WHY: See how each category's total viewership changes weekly
-- Teaching: Demonstrates window functions for running totals

SELECT
    week,
    category,
    SUM(weekly_hours_viewed) AS weekly_category_hours,
    -- Running total (cumulative sum up to this week)
    SUM(SUM(weekly_hours_viewed)) OVER (
        PARTITION BY category
        ORDER BY week
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_hours,
    -- WHY: PARTITION BY resets the sum for each category
    -- WHY: UNBOUNDED PRECEDING means "from the beginning"
    RANK() OVER (
        PARTITION BY week
        ORDER BY SUM(weekly_hours_viewed) DESC
    ) AS category_rank_that_week
    -- WHY: Which category was #1 each week?
FROM NETFLIX_WEEKLY_VIEWS
GROUP BY week, category
ORDER BY week DESC, category_rank_that_week;

-- ============================================================
-- QUERY 5: Biggest Drops from Rank 1
-- ============================================================
-- WHY: Find shows that were #1 but then fell significantly
-- Teaching: Demonstrates self-joins and ranking

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
    -- WHY: Positive number = dropped in ranking
    CASE
        WHEN weekly_rank - previous_week_rank >= 5 THEN 'DROPPED SIGNIFICANTLY'
        WHEN weekly_rank - previous_week_rank >= 3 THEN 'dropped moderately'
        ELSE 'slight drop'
    END AS severity
FROM weekly_ranks
WHERE previous_week_rank IS NOT NULL
  AND weekly_rank > previous_week_rank   -- Only show drops (rank got worse)
ORDER BY rank_drop DESC, week
LIMIT 15;

-- ============================================================
-- QUERY 6: "Long Tail" Analysis — Shows That Stay Long
-- ============================================================
-- WHY: Identify content with long-term staying power vs one-week wonders
-- Teaching: Demonstrates CASE WHEN for categorization

SELECT
    show_title,
    category,
    MAX(cumulative_weeks_in_top_10) AS total_weeks_in_top_10,
    SUM(weekly_hours_viewed) AS total_hours_viewed,
    -- ---- Categorize longevity ----
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
-- WHY: See monthly patterns — when do people watch more?
-- Teaching: Demonstrates DATE_TRUNC for date grouping

SELECT
    DATE_TRUNC('MONTH', week) AS month,
    -- WHY: DATE_TRUNC rounds down to the first day of the month
    -- '2026-05-17' becomes '2026-05-01'

    COUNT(DISTINCT week) AS weeks_in_month,
    SUM(weekly_hours_viewed) AS total_hours_viewed,
    ROUND(SUM(weekly_hours_viewed) / 1e9, 2) AS total_hours_billions,
    -- WHY: Divides by 1 billion for readability
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

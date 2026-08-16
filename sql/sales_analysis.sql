-- Analytical queries against data/processed/pharma_sales.db (SQLite).
-- Schema: sql/schema.sql (dim_category, fact_sales). Run after notebooks/01_data_cleaning.ipynb
-- has populated fact_sales.


-- ============================================================
-- 1. Monthly aggregation by category, built directly from daily
--    granularity (demonstrates GROUP BY + strftime rather than
--    relying on the pre-aggregated monthly rows already in
--    fact_sales).
-- ============================================================
SELECT
    strftime('%Y-%m', f.sale_date) AS sale_month,
    d.category_name,
    ROUND(SUM(f.units_sold), 1) AS total_units,
    ROUND(AVG(f.units_sold), 2) AS avg_daily_units
FROM fact_sales f
JOIN dim_category d ON d.category_code = f.category_code
WHERE f.granularity = 'daily'
GROUP BY sale_month, d.category_name
ORDER BY sale_month, total_units DESC;


-- ============================================================
-- 2. 3-month rolling average per category (monthly granularity),
--    using a window function rather than a self-join.
-- ============================================================
SELECT
    f.category_code,
    d.category_name,
    f.sale_date,
    f.units_sold,
    ROUND(AVG(f.units_sold) OVER (
        PARTITION BY f.category_code
        ORDER BY f.sale_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1) AS rolling_3month_avg
FROM fact_sales f
JOIN dim_category d ON d.category_code = f.category_code
WHERE f.granularity = 'monthly'
ORDER BY f.category_code, f.sale_date;


-- ============================================================
-- 3. Month-over-month % growth per category (LAG window function).
-- ============================================================
SELECT
    f.category_code,
    d.category_name,
    f.sale_date,
    f.units_sold,
    LAG(f.units_sold) OVER (PARTITION BY f.category_code ORDER BY f.sale_date) AS prior_month_units,
    ROUND(
        100.0 * (f.units_sold - LAG(f.units_sold) OVER (PARTITION BY f.category_code ORDER BY f.sale_date))
        / NULLIF(LAG(f.units_sold) OVER (PARTITION BY f.category_code ORDER BY f.sale_date), 0),
        1
    ) AS mom_growth_pct
FROM fact_sales f
JOIN dim_category d ON d.category_code = f.category_code
WHERE f.granularity = 'monthly'
ORDER BY f.category_code, f.sale_date;


-- ============================================================
-- 4. Year-over-year % growth per category (LAG 12 rows back on
--    monthly granularity).
-- ============================================================
SELECT
    f.category_code,
    d.category_name,
    f.sale_date,
    f.units_sold,
    LAG(f.units_sold, 12) OVER (PARTITION BY f.category_code ORDER BY f.sale_date) AS same_month_last_year,
    ROUND(
        100.0 * (f.units_sold - LAG(f.units_sold, 12) OVER (PARTITION BY f.category_code ORDER BY f.sale_date))
        / NULLIF(LAG(f.units_sold, 12) OVER (PARTITION BY f.category_code ORDER BY f.sale_date), 0),
        1
    ) AS yoy_growth_pct
FROM fact_sales f
JOIN dim_category d ON d.category_code = f.category_code
WHERE f.granularity = 'monthly'
ORDER BY f.category_code, f.sale_date;


-- ============================================================
-- 5. Rank categories by total volume within each year
--    (RANK() window function).
-- ============================================================
SELECT
    sale_year,
    category_name,
    total_units,
    RANK() OVER (PARTITION BY sale_year ORDER BY total_units DESC) AS volume_rank
FROM (
    SELECT
        strftime('%Y', f.sale_date) AS sale_year,
        d.category_name,
        SUM(f.units_sold) AS total_units
    FROM fact_sales f
    JOIN dim_category d ON d.category_code = f.category_code
    WHERE f.granularity = 'monthly'
    GROUP BY sale_year, d.category_name
)
ORDER BY sale_year, volume_rank;


-- ============================================================
-- 6. Gap detection: months where a category's reported total is
--    zero. Returns 0 rows against fact_sales as loaded, because
--    notebooks/01_data_cleaning.ipynb already patched the one real
--    gap in the source data (January 2017 reported 0.0 for 7 of 8
--    categories) using the daily-rollup total before loading into
--    this database. Kept here as the general-purpose check that
--    would have caught it had the fix not already been applied.
-- ============================================================
SELECT
    f.category_code,
    d.category_name,
    f.sale_date,
    f.units_sold
FROM fact_sales f
JOIN dim_category d ON d.category_code = f.category_code
WHERE f.granularity = 'monthly'
  AND f.units_sold = 0
ORDER BY f.sale_date, f.category_code;


-- ============================================================
-- 7. Consecutive-date gap check on the daily granularity: flags
--    any pair of consecutive rows per category more than 1 day
--    apart (there are none in this dataset -- notebooks/02_eda.ipynb
--    confirmed 2,106/2,106 calendar days present -- but the query
--    is kept here as the general-purpose check).
-- ============================================================
SELECT
    category_code,
    sale_date,
    prior_date,
    julianday(sale_date) - julianday(prior_date) AS days_since_prior
FROM (
    SELECT
        category_code,
        sale_date,
        LAG(sale_date) OVER (PARTITION BY category_code ORDER BY sale_date) AS prior_date
    FROM fact_sales
    WHERE granularity = 'daily'
)
WHERE julianday(sale_date) - julianday(prior_date) > 1;

-- Active: 1758948723040@@127.0.0.1@3306@sales_intelligence
-- Revenue Analysis
-- Source tables: fact_order, dim_date
-- Business definitions per docs/business_requirements.md Section 4 (Financial Metrics)
-- and docs/data_dictionary.md (Business Metric Definitions).
--
-- Notes:
--   - "Total Revenue" uses fact_order.payment_value (sum of order_payments),
--     consistent with the business rule: "Revenue should be calculated
--     consistently across all reports."
--   - Cancelled/unavailable orders are NOT excluded by default in these
--     queries; a separate query below reports revenue by status so the
--     exclusion can be applied explicitly downstream (per business rule:
--     "Cancelled and unavailable orders should be excluded from revenue
--     unless explicitly analyzed.").

USE sales_intelligence;

-- ---------------------------------------------------------------------------
-- 1. Monthly revenue and order trend
-- ---------------------------------------------------------------------------
-- Mirrors the `monthly_orders` aggregation from data_exploration.ipynb.

SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.payment_value) AS total_revenue,
    SUM(fo.payment_value) / COUNT(DISTINCT fo.order_id) AS avg_order_value
FROM fact_order fo
INNER JOIN dim_date d
    ON fo.purchase_date_key = d.date_key
GROUP BY d.year_number, d.month_number, d.month_name
ORDER BY d.year_number, d.month_number;

-- ---------------------------------------------------------------------------
-- 2. Month-over-month revenue growth %
-- ---------------------------------------------------------------------------
-- Formula per business_requirements.md:
--   (Current Period Revenue - Previous Period Revenue) / Previous Period Revenue * 100

WITH monthly_revenue AS (
    SELECT
        d.year_number,
        d.month_number,
        SUM(fo.payment_value) AS revenue
    FROM fact_order fo
    INNER JOIN dim_date d
        ON fo.purchase_date_key = d.date_key
    GROUP BY d.year_number, d.month_number
)
SELECT
    year_number,
    month_number,
    revenue,
    LAG(revenue) OVER (ORDER BY year_number, month_number) AS prior_month_revenue,
    CASE
        WHEN LAG(revenue) OVER (ORDER BY year_number, month_number) IS NULL
            OR LAG(revenue) OVER (ORDER BY year_number, month_number) = 0
        THEN NULL
        ELSE (revenue - LAG(revenue) OVER (ORDER BY year_number, month_number))
            / LAG(revenue) OVER (ORDER BY year_number, month_number) * 100
    END AS revenue_growth_pct
FROM monthly_revenue
ORDER BY year_number, month_number;

-- ---------------------------------------------------------------------------
-- 3. Revenue by order status
-- ---------------------------------------------------------------------------
-- Use this to validate/apply the cancelled-and-unavailable exclusion rule
-- before reporting headline revenue figures.

SELECT
    order_status,
    COUNT(*) AS orders,
    SUM(payment_value) AS payment_revenue,
    SUM(merchandise_value) AS merchandise_revenue,
    SUM(freight_value) AS freight_revenue
FROM fact_order
GROUP BY order_status
ORDER BY payment_revenue DESC;

-- ---------------------------------------------------------------------------
-- 4. Total revenue excluding cancelled/unavailable orders
-- ---------------------------------------------------------------------------
-- This is the "clean" headline figure per the business rule on exclusions.

SELECT
    COUNT(DISTINCT order_id) AS orders,
    SUM(payment_value) AS total_revenue,
    SUM(payment_value) / COUNT(DISTINCT order_id) AS avg_order_value
FROM fact_order
WHERE order_status NOT IN ('canceled', 'unavailable');

-- ---------------------------------------------------------------------------
-- 5. Revenue and freight breakdown (merchandise vs. freight split)
-- ---------------------------------------------------------------------------
-- Useful for understanding how much of payment_value is shipping cost
-- versus merchandise value.

SELECT
    d.year_number,
    d.month_number,
    SUM(fo.merchandise_value) AS merchandise_revenue,
    SUM(fo.freight_value) AS freight_revenue,
    SUM(fo.payment_value) AS total_payment_value,
    SUM(fo.freight_value) / NULLIF(SUM(fo.merchandise_value), 0) AS freight_rate
FROM fact_order fo
INNER JOIN dim_date d
    ON fo.purchase_date_key = d.date_key
GROUP BY d.year_number, d.month_number
ORDER BY d.year_number, d.month_number;

-- ---------------------------------------------------------------------------
-- 6. Payment type mix (transactions, value, avg installments)
-- ---------------------------------------------------------------------------
-- Note: this requires raw_order_payments since payment_type/installments
-- are not carried into fact_order (which stores only the summed
-- payment_value per order). Included here for completeness of financial
-- reporting.

SELECT
    payment_type,
    COUNT(*) AS transactions,
    SUM(payment_value) AS payment_value,
    AVG(payment_value) AS avg_payment_value,
    AVG(payment_installments) AS avg_installments
FROM raw_order_payments
GROUP BY payment_type
ORDER BY payment_value DESC;
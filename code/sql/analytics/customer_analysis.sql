-- Customer Analysis
-- Source tables: fact_order, dim_customer, dim_date
-- Business definitions per docs/business_requirements.md Section 4 (Customer Metrics)
-- and docs/data_dictionary.md.
--
-- Notes:
--   - Repeat purchase rate MUST use customer_unique_id, not customer_id,
--     per business rule. dim_customer.total_orders is already aggregated
--     at the customer_unique_id grain, so it is used directly here.

USE sales_intelligence;

-- ---------------------------------------------------------------------------
-- 1. Total customers and repeat purchase rate
-- ---------------------------------------------------------------------------
-- Formula per business_requirements.md:
--   Repeat Purchase Rate = Customers with 2+ Orders / Total Customers * 100

SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN total_orders >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    SUM(CASE WHEN total_orders >= 2 THEN 1 ELSE 0 END) / COUNT(*) * 100 AS repeat_purchase_rate_pct
FROM dim_customer;

-- ---------------------------------------------------------------------------
-- 2. New customers per month (based on first_order_date)
-- ---------------------------------------------------------------------------
-- "New" is defined as a customer's first-ever order falling in that month.

SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    COUNT(DISTINCT c.customer_unique_id) AS new_customers
FROM dim_customer c
INNER JOIN dim_date d
    ON CAST(DATE_FORMAT(DATE(c.first_order_date), '%Y%m%d') AS UNSIGNED) = d.date_key
GROUP BY d.year_number, d.month_number, d.month_name
ORDER BY d.year_number, d.month_number;

-- ---------------------------------------------------------------------------
-- 3. Cumulative customer growth over time
-- ---------------------------------------------------------------------------
-- Running total of distinct customers acquired, month over month.

WITH monthly_new_customers AS (
    SELECT
        d.year_number,
        d.month_number,
        COUNT(DISTINCT c.customer_unique_id) AS new_customers
    FROM dim_customer c
    INNER JOIN dim_date d
        ON CAST(DATE_FORMAT(DATE(c.first_order_date), '%Y%m%d') AS UNSIGNED) = d.date_key
    GROUP BY d.year_number, d.month_number
)
SELECT
    year_number,
    month_number,
    new_customers,
    SUM(new_customers) OVER (
        ORDER BY year_number, month_number
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_customers
FROM monthly_new_customers
ORDER BY year_number, month_number;

-- ---------------------------------------------------------------------------
-- 4. Orders and revenue by customer state
-- ---------------------------------------------------------------------------
-- Mirrors the `state_sales` aggregation from data_exploration.ipynb.

SELECT
    c.customer_state,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.payment_value) AS revenue,
    COUNT(DISTINCT fo.customer_unique_id) AS customers
FROM fact_order fo
INNER JOIN dim_customer c
    ON fo.customer_unique_id = c.customer_unique_id
GROUP BY c.customer_state
ORDER BY orders DESC;

-- ---------------------------------------------------------------------------
-- 5. Orders and revenue by customer city (top cities)
-- ---------------------------------------------------------------------------
-- Mirrors the `city_sales` aggregation from data_exploration.ipynb.

SELECT
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.payment_value) AS revenue
FROM fact_order fo
INNER JOIN dim_customer c
    ON fo.customer_unique_id = c.customer_unique_id
GROUP BY c.customer_state, c.customer_city
ORDER BY orders DESC;

-- ---------------------------------------------------------------------------
-- 6. Customer order frequency distribution
-- ---------------------------------------------------------------------------
-- Shows how many customers placed 1, 2, 3, ... orders. Useful context
-- alongside the repeat purchase rate headline metric.

SELECT
    total_orders,
    COUNT(*) AS customers
FROM dim_customer
GROUP BY total_orders
ORDER BY total_orders;  

-- ---------------------------------------------------------------------------
-- 7. Average customer lifetime value (paid revenue per customer)
-- ---------------------------------------------------------------------------

SELECT
    c.customer_unique_id,
    c.total_orders,
    SUM(fo.payment_value) AS lifetime_revenue,
    SUM(fo.payment_value) / c.total_orders AS avg_order_value
FROM dim_customer c
INNER JOIN fact_order fo
    ON c.customer_unique_id = fo.customer_unique_id
GROUP BY c.customer_unique_id, c.total_orders
ORDER BY lifetime_revenue DESC;
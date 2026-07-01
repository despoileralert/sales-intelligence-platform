-- Regional Analysis
-- Source tables: fact_order, fact_review, dim_customer, dim_seller, dim_date
-- Business definitions per docs/business_requirements.md Section 4
-- (Operations Metrics) and docs/data_dictionary.md.
--
-- Notes:
--   - This file focuses on the delivery/fulfillment and geography angle.
--     Customer acquisition/revenue-by-state metrics live in
--     customer_analysis.sql to avoid duplicating that view.
--   - Delivery metrics only include orders with a valid
--     order_delivered_customer_date, per the business rule:
--     "Delivery metrics should only include orders with a valid
--     delivered customer date."

USE sales_intelligence;

-- ---------------------------------------------------------------------------
-- 1. Late delivery rate and median delivery days by customer state
-- ---------------------------------------------------------------------------
-- Mirrors the `late_by_state` aggregation from data_exploration.ipynb.
-- Note: MySQL has no built-in MEDIAN, so this uses PERCENT_RANK to
-- approximate the median delivery_days per state.

WITH delivered_orders AS (
    SELECT
        c.customer_state,
        fo.order_id,
        fo.delivery_days,
        fo.late_delivery_flag
    FROM fact_order fo
    INNER JOIN dim_customer c
        ON fo.customer_unique_id = c.customer_unique_id
    WHERE fo.order_delivered_customer_date IS NOT NULL
),
ranked AS (
    SELECT
        customer_state,
        delivery_days,
        late_delivery_flag,
        PERCENT_RANK() OVER (PARTITION BY customer_state ORDER BY delivery_days) AS pct_rank
    FROM delivered_orders
)
SELECT
    d.customer_state,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN d.late_delivery_flag THEN 1 ELSE 0 END) / COUNT(*) * 100 AS late_delivery_rate_pct,
    (
        SELECT AVG(delivery_days)
        FROM ranked r
        WHERE r.customer_state = d.customer_state
            AND r.pct_rank BETWEEN 0.45 AND 0.55
    ) AS median_delivery_days_approx,
    AVG(d.delivery_days) AS avg_delivery_days
FROM delivered_orders d
GROUP BY d.customer_state
ORDER BY late_delivery_rate_pct DESC;

-- ---------------------------------------------------------------------------
-- 2. Orders and revenue by seller state
-- ---------------------------------------------------------------------------
-- Fulfillment-side counterpart to the customer-state revenue view in
-- customer_analysis.sql. Note: this is at the order-item grain since
-- seller is only known per line item, not per order.

SELECT
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS orders,
    COUNT(*) AS order_items,
    SUM(oi.price) AS merchandise_revenue,
    COUNT(DISTINCT oi.seller_id) AS sellers
FROM fact_order_item oi
INNER JOIN dim_seller s
    ON oi.seller_id = s.seller_id
GROUP BY s.seller_state
ORDER BY merchandise_revenue DESC;

-- ---------------------------------------------------------------------------
-- 3. Seller state -> customer state cross-tab (shipping distance proxy)
-- ---------------------------------------------------------------------------
-- Compares same-state vs. cross-state deliveries and their delivery
-- performance, as a rough proxy for shipping distance impact.

SELECT
    s.seller_state,
    c.customer_state,
    CASE WHEN s.seller_state = c.customer_state THEN 'Same State' ELSE 'Different State' END AS route_type,
    COUNT(DISTINCT oi.order_id) AS orders,
    AVG(fo.delivery_days) AS avg_delivery_days,
    SUM(CASE WHEN fo.late_delivery_flag THEN 1 ELSE 0 END) / COUNT(DISTINCT oi.order_id) * 100 AS late_delivery_rate_pct
FROM fact_order_item oi
INNER JOIN dim_seller s
    ON oi.seller_id = s.seller_id
INNER JOIN fact_order fo
    ON oi.order_id = fo.order_id
INNER JOIN dim_customer c
    ON fo.customer_unique_id = c.customer_unique_id
WHERE fo.order_delivered_customer_date IS NOT NULL
GROUP BY s.seller_state, c.customer_state
ORDER BY orders DESC
LIMIT 30;

-- ---------------------------------------------------------------------------
-- 4. Same-state vs. different-state delivery performance (summary)
-- ---------------------------------------------------------------------------
-- Aggregated version of query 3, collapsed to just the two route types
-- for a simple Power BI comparison card/chart.

SELECT
    CASE WHEN s.seller_state = c.customer_state THEN 'Same State' ELSE 'Different State' END AS route_type,
    COUNT(DISTINCT oi.order_id) AS orders,
    AVG(fo.delivery_days) AS avg_delivery_days,
    SUM(CASE WHEN fo.late_delivery_flag THEN 1 ELSE 0 END) / COUNT(DISTINCT oi.order_id) * 100 AS late_delivery_rate_pct
FROM fact_order_item oi
INNER JOIN dim_seller s
    ON oi.seller_id = s.seller_id
INNER JOIN fact_order fo
    ON oi.order_id = fo.order_id
INNER JOIN dim_customer c
    ON fo.customer_unique_id = c.customer_unique_id
WHERE fo.order_delivered_customer_date IS NOT NULL
GROUP BY route_type;

-- ---------------------------------------------------------------------------
-- 5. Average review score by customer state
-- ---------------------------------------------------------------------------
-- Regional satisfaction view, useful to cross-reference against the
-- late delivery rate by state in query 1.

SELECT
    c.customer_state,
    COUNT(DISTINCT fr.review_id) AS reviews,
    AVG(fr.review_score) AS avg_review_score,
    SUM(CASE WHEN fr.is_negative_review THEN 1 ELSE 0 END) / COUNT(DISTINCT fr.review_id) * 100 AS negative_review_rate_pct
FROM fact_review fr
INNER JOIN fact_order fo
    ON fr.order_id = fo.order_id
INNER JOIN dim_customer c
    ON fo.customer_unique_id = c.customer_unique_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT fr.review_id) >= 30
ORDER BY avg_review_score ASC;

-- ---------------------------------------------------------------------------
-- 6. Late delivery rate and revenue by state and month (trended)
-- ---------------------------------------------------------------------------
-- Trended version of query 1, for a Power BI map or line chart with a
-- time slicer.

SELECT
    d.year_number,
    d.month_number,
    c.customer_state,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.payment_value) AS revenue,
    SUM(CASE WHEN fo.late_delivery_flag THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN fo.order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END), 0) * 100
        AS late_delivery_rate_pct
FROM fact_order fo
INNER JOIN dim_customer c
    ON fo.customer_unique_id = c.customer_unique_id
INNER JOIN dim_date d
    ON fo.purchase_date_key = d.date_key
GROUP BY d.year_number, d.month_number, c.customer_state
ORDER BY d.year_number, d.month_number, orders DESC;
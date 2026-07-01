-- Product Analysis
-- Source tables: fact_order_item, fact_order, fact_review, dim_product,
--                dim_seller, dim_date
-- Business definitions per docs/business_requirements.md and
-- docs/data_dictionary.md.
--
-- Notes:
--   - "Category" uses product_category_name_english for reporting,
--     per the recommendation in data_dictionary.md.
--   - freight_rate on fact_order_item is freight_value / price at the
--     line-item grain; category-level freight rate here is recomputed
--     as SUM(freight)/SUM(price) to avoid averaging ratios of ratios.

USE sales_intelligence;

-- ---------------------------------------------------------------------------
-- 1. Top categories by revenue, items, and freight
-- ---------------------------------------------------------------------------
-- Mirrors the `category_sales` aggregation from data_exploration.ipynb.

SELECT
    p.product_category_name_english AS category,
    COUNT(*) AS order_items,
    SUM(oi.price) AS merchandise_revenue,
    SUM(oi.freight_value) AS freight_revenue,
    COUNT(DISTINCT oi.seller_id) AS sellers,
    COUNT(DISTINCT oi.order_id) AS orders
FROM fact_order_item oi
INNER JOIN dim_product p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name_english
ORDER BY merchandise_revenue DESC;

-- ---------------------------------------------------------------------------
-- 2. Top sellers by revenue
-- ---------------------------------------------------------------------------
-- Mirrors the `seller_sales` aggregation from data_exploration.ipynb.

SELECT
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(*) AS order_items,
    SUM(oi.price) AS merchandise_revenue,
    SUM(oi.freight_value) AS freight_revenue,
    COUNT(DISTINCT p.product_category_name_english) AS categories,
    COUNT(DISTINCT oi.order_id) AS orders
FROM fact_order_item oi
INNER JOIN dim_seller s
    ON oi.seller_id = s.seller_id
INNER JOIN dim_product p
    ON oi.product_id = p.product_id
GROUP BY s.seller_id, s.seller_state, s.seller_city
ORDER BY merchandise_revenue DESC;

-- ---------------------------------------------------------------------------
-- 3. Category freight rate (freight as % of merchandise value)
-- ---------------------------------------------------------------------------
-- Highlights categories where shipping cost eats disproportionately into
-- the order value, e.g. bulky/heavy items.

SELECT
    p.product_category_name_english AS category,
    SUM(oi.price) AS merchandise_revenue,
    SUM(oi.freight_value) AS freight_revenue,
    SUM(oi.freight_value) / NULLIF(SUM(oi.price), 0) * 100 AS freight_rate_pct
FROM fact_order_item oi
INNER JOIN dim_product p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name_english
HAVING SUM(oi.price) > 0
ORDER BY freight_rate_pct DESC;

-- ---------------------------------------------------------------------------
-- 4. Seller concentration (revenue share by seller)
-- ---------------------------------------------------------------------------
-- Flags concentration risk: are a small number of sellers driving most
-- of total merchandise revenue?

WITH seller_revenue AS (
    SELECT
        seller_id,
        SUM(price) AS merchandise_revenue
    FROM fact_order_item
    GROUP BY seller_id
),
totals AS (
    SELECT SUM(merchandise_revenue) AS total_revenue
    FROM seller_revenue
)
SELECT
    sr.seller_id,
    sr.merchandise_revenue,
    sr.merchandise_revenue / t.total_revenue * 100 AS pct_of_total_revenue,
    RANK() OVER (ORDER BY sr.merchandise_revenue DESC) AS revenue_rank
FROM seller_revenue sr
CROSS JOIN totals t
ORDER BY sr.merchandise_revenue DESC;

-- ---------------------------------------------------------------------------
-- 5. Average review score by product category
-- ---------------------------------------------------------------------------
-- Joins reviews (order grain) through order items to product category.
-- Note: an order can contain multiple categories, so a review is counted
-- once per distinct category present in that order.

SELECT
    p.product_category_name_english AS category,
    COUNT(DISTINCT fr.review_id) AS reviews,
    AVG(fr.review_score) AS avg_review_score,
    SUM(CASE WHEN fr.is_negative_review THEN 1 ELSE 0 END) / COUNT(DISTINCT fr.review_id) * 100 AS negative_review_rate_pct
FROM fact_review fr
INNER JOIN fact_order_item oi
    ON fr.order_id = oi.order_id
INNER JOIN dim_product p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name_english
HAVING COUNT(DISTINCT fr.review_id) >= 30
ORDER BY avg_review_score ASC;

-- ---------------------------------------------------------------------------
-- 6. Average items per order by category
-- ---------------------------------------------------------------------------
-- Basket composition signal: which categories tend to be bought in bulk
-- vs. as single-item purchases.

SELECT
    p.product_category_name_english AS category,
    COUNT(*) AS order_items,
    COUNT(DISTINCT oi.order_id) AS orders,
    COUNT(*) / COUNT(DISTINCT oi.order_id) AS avg_items_per_order
FROM fact_order_item oi
INNER JOIN dim_product p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name_english
ORDER BY avg_items_per_order DESC;

-- ---------------------------------------------------------------------------
-- 7. Category revenue trend by month
-- ---------------------------------------------------------------------------
-- Trended version of query 1, for category performance over time in
-- Power BI (e.g. line chart with category as a legend/filter).

SELECT
    d.year_number,
    d.month_number,
    p.product_category_name_english AS category,
    COUNT(*) AS order_items,
    SUM(oi.price) AS merchandise_revenue
FROM fact_order_item oi
INNER JOIN dim_product p
    ON oi.product_id = p.product_id
INNER JOIN dim_date d
    ON oi.shipping_limit_date_key = d.date_key
GROUP BY d.year_number, d.month_number, p.product_category_name_english
ORDER BY d.year_number, d.month_number, merchandise_revenue DESC;
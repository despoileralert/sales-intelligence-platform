-- Active: 1782354710076@@127.0.0.1@3306@sales_intelligence
-- Transform raw Olist staging tables into the analytical star schema.
-- Run this after:
--   1. sql/ddl/schema.sql
--   2. sql/dml/load_raw_data.sql

USE sales_intelligence;

-- Compatibility for databases created before review timestamps were nullable.
-- The Olist review file can produce zero/blank datetime values under some
-- MySQL load settings, so keep raw review timestamps nullable.
ALTER TABLE raw_order_reviews
    MODIFY review_creation_date DATETIME NULL,
    MODIFY review_answer_timestamp DATETIME NULL;

ALTER TABLE fact_review
    MODIFY review_answer_timestamp DATETIME NULL;

-- Make the script rerunnable during development.
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE fact_review;
TRUNCATE TABLE fact_order_item;
TRUNCATE TABLE fact_order;
TRUNCATE TABLE dim_seller;
TRUNCATE TABLE dim_product;
TRUNCATE TABLE dim_customer;
TRUNCATE TABLE dim_date;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- Dimension: date
-- ---------------------------------------------------------------------------
-- This creates one calendar row for every date that appears in the source data.

INSERT INTO dim_date (
    date_key,
    full_date,
    year_number,
    quarter_number,
    month_number,
    month_name,
    week_number,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
)
SELECT
    CAST(DATE_FORMAT(full_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    full_date,
    YEAR(full_date) AS year_number,
    QUARTER(full_date) AS quarter_number,
    MONTH(full_date) AS month_number,
    MONTHNAME(full_date) AS month_name,
    WEEK(full_date, 3) AS week_number,
    DAYOFMONTH(full_date) AS day_of_month,
    DAYOFWEEK(full_date) AS day_of_week,
    DAYNAME(full_date) AS day_name,
    DAYOFWEEK(full_date) IN (1, 7) AS is_weekend
FROM (
    SELECT DISTINCT DATE(order_purchase_timestamp) AS full_date FROM raw_orders
    UNION
    SELECT DISTINCT DATE(order_approved_at) FROM raw_orders WHERE order_approved_at IS NOT NULL
    UNION
    SELECT DISTINCT DATE(order_delivered_carrier_date) FROM raw_orders WHERE order_delivered_carrier_date IS NOT NULL
    UNION
    SELECT DISTINCT DATE(order_delivered_customer_date) FROM raw_orders WHERE order_delivered_customer_date IS NOT NULL
    UNION
    SELECT DISTINCT DATE(order_estimated_delivery_date) FROM raw_orders
    UNION
    SELECT DISTINCT DATE(shipping_limit_date) FROM raw_order_items
    UNION
    SELECT DISTINCT DATE(review_creation_date)
    FROM raw_order_reviews
    WHERE review_creation_date IS NOT NULL
        AND CAST(review_creation_date AS CHAR) <> '0000-00-00 00:00:00'
) AS source_dates
WHERE full_date IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Dimension: customer
-- ---------------------------------------------------------------------------
-- Grain: one row per customer_unique_id.
-- The location fields use the most recent known customer record.

INSERT INTO dim_customer (
    customer_unique_id,
    first_customer_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix,
    first_order_date,
    last_order_date,
    total_orders
)
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        c.customer_id,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp ASC, c.customer_id ASC
        ) AS first_order_rank,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp DESC, c.customer_id DESC
        ) AS latest_order_rank
    FROM raw_customers c
    LEFT JOIN raw_orders o
        ON c.customer_id = o.customer_id
)
SELECT
    customer_unique_id,
    MAX(CASE WHEN first_order_rank = 1 THEN customer_id END) AS first_customer_id,
    MAX(CASE WHEN latest_order_rank = 1 THEN customer_city END) AS customer_city,
    MAX(CASE WHEN latest_order_rank = 1 THEN customer_state END) AS customer_state,
    MAX(CASE WHEN latest_order_rank = 1 THEN customer_zip_code_prefix END) AS customer_zip_code_prefix,
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date,
    COUNT(order_purchase_timestamp) AS total_orders
FROM customer_orders
GROUP BY customer_unique_id;

-- ---------------------------------------------------------------------------
-- Dimension: product
-- ---------------------------------------------------------------------------
-- Grain: one row per product_id.

INSERT INTO dim_product (
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_volume_cm3
)
SELECT
    p.product_id,
    COALESCE(NULLIF(p.product_category_name, ''), 'unknown') AS product_category_name,
    COALESCE(NULLIF(t.product_category_name_english, ''), 'unknown') AS product_category_name_english,
    p.product_name_lenght AS product_name_length,
    p.product_description_lenght AS product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    CASE
        WHEN p.product_length_cm IS NULL
            OR p.product_height_cm IS NULL
            OR p.product_width_cm IS NULL
        THEN NULL
        ELSE p.product_length_cm * p.product_height_cm * p.product_width_cm
    END AS product_volume_cm3
FROM raw_products p
LEFT JOIN raw_product_category_translation t
    ON p.product_category_name = t.product_category_name;

-- ---------------------------------------------------------------------------
-- Dimension: seller
-- ---------------------------------------------------------------------------
-- Grain: one row per seller_id.

INSERT INTO dim_seller (
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
)
SELECT
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
FROM raw_sellers;

-- ---------------------------------------------------------------------------
-- Fact: order
-- ---------------------------------------------------------------------------
-- Grain: one row per order_id.
-- Payments and order items are aggregated before joining to preserve order grain.

INSERT INTO fact_order (
    order_id,
    customer_id,
    customer_unique_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    purchase_date_key,
    approved_date_key,
    delivered_carrier_date_key,
    delivered_customer_date_key,
    estimated_delivery_date_key,
    payment_value,
    merchandise_value,
    freight_value,
    item_count,
    seller_count,
    approval_days,
    carrier_handling_days,
    delivery_days,
    estimated_delivery_days,
    late_delivery_flag
)
WITH payment_summary AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM raw_order_payments
    GROUP BY order_id
),
item_summary AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value,
        COUNT(*) AS item_count,
        COUNT(DISTINCT seller_id) AS seller_count
    FROM raw_order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    CAST(DATE_FORMAT(DATE(o.order_purchase_timestamp), '%Y%m%d') AS UNSIGNED) AS purchase_date_key,
    CAST(DATE_FORMAT(DATE(o.order_approved_at), '%Y%m%d') AS UNSIGNED) AS approved_date_key,
    CAST(DATE_FORMAT(DATE(o.order_delivered_carrier_date), '%Y%m%d') AS UNSIGNED) AS delivered_carrier_date_key,
    CAST(DATE_FORMAT(DATE(o.order_delivered_customer_date), '%Y%m%d') AS UNSIGNED) AS delivered_customer_date_key,
    CAST(DATE_FORMAT(DATE(o.order_estimated_delivery_date), '%Y%m%d') AS UNSIGNED) AS estimated_delivery_date_key,
    COALESCE(ps.payment_value, 0) AS payment_value,
    COALESCE(its.merchandise_value, 0) AS merchandise_value,
    COALESCE(its.freight_value, 0) AS freight_value,
    COALESCE(its.item_count, 0) AS item_count,
    COALESCE(its.seller_count, 0) AS seller_count,
    CASE
        WHEN o.order_approved_at IS NULL THEN NULL
        ELSE TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_approved_at) / 24
    END AS approval_days,
    CASE
        WHEN o.order_approved_at IS NULL OR o.order_delivered_carrier_date IS NULL THEN NULL
        ELSE TIMESTAMPDIFF(HOUR, o.order_approved_at, o.order_delivered_carrier_date) / 24
    END AS carrier_handling_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        ELSE TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24
    END AS delivery_days,
    TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_estimated_delivery_date) / 24 AS estimated_delivery_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        ELSE o.order_delivered_customer_date > o.order_estimated_delivery_date
    END AS late_delivery_flag
FROM raw_orders o
INNER JOIN raw_customers c
    ON o.customer_id = c.customer_id
LEFT JOIN payment_summary ps
    ON o.order_id = ps.order_id
LEFT JOIN item_summary its
    ON o.order_id = its.order_id;

-- ---------------------------------------------------------------------------
-- Fact: order item
-- ---------------------------------------------------------------------------
-- Grain: one row per order_id and order_item_id.

INSERT INTO fact_order_item (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    shipping_limit_date_key,
    price,
    freight_value,
    line_total_value,
    freight_rate
)
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    CAST(DATE_FORMAT(DATE(oi.shipping_limit_date), '%Y%m%d') AS UNSIGNED) AS shipping_limit_date_key,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS line_total_value,
    CASE
        WHEN oi.price = 0 THEN NULL
        ELSE oi.freight_value / oi.price
    END AS freight_rate
FROM raw_order_items oi
INNER JOIN fact_order fo
    ON oi.order_id = fo.order_id
INNER JOIN dim_product p
    ON oi.product_id = p.product_id
INNER JOIN dim_seller s
    ON oi.seller_id = s.seller_id;

-- ---------------------------------------------------------------------------
-- Fact: review
-- ---------------------------------------------------------------------------
-- Grain: one row per review_id.

INSERT INTO fact_review (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    review_creation_date_key,
    review_response_days,
    has_review_comment,
    is_negative_review,
    is_positive_review
)
SELECT
    r.review_id,
    r.order_id,
    r.review_score,
    NULLIF(r.review_comment_title, '') AS review_comment_title,
    NULLIF(r.review_comment_message, '') AS review_comment_message,
    r.review_creation_date,
    CASE
        WHEN r.review_answer_timestamp IS NULL
            OR CAST(r.review_answer_timestamp AS CHAR) = '0000-00-00 00:00:00'
        THEN NULL
        ELSE r.review_answer_timestamp
    END AS review_answer_timestamp,
    CAST(DATE_FORMAT(DATE(r.review_creation_date), '%Y%m%d') AS UNSIGNED) AS review_creation_date_key,
    CASE
        WHEN r.review_answer_timestamp IS NULL
            OR CAST(r.review_answer_timestamp AS CHAR) = '0000-00-00 00:00:00'
        THEN NULL
        ELSE TIMESTAMPDIFF(HOUR, r.review_creation_date, r.review_answer_timestamp) / 24
    END AS review_response_days,
    NULLIF(TRIM(r.review_comment_message), '') IS NOT NULL AS has_review_comment,
    r.review_score <= 2 AS is_negative_review,
    r.review_score >= 4 AS is_positive_review
FROM raw_order_reviews r
INNER JOIN fact_order fo
    ON r.order_id = fo.order_id
WHERE r.review_creation_date IS NOT NULL
    AND CAST(r.review_creation_date AS CHAR) <> '0000-00-00 00:00:00';

-- ---------------------------------------------------------------------------
-- Post-transform sanity checks
-- ---------------------------------------------------------------------------

SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dim_date
UNION ALL
SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL
SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL
SELECT 'fact_order', COUNT(*) FROM fact_order
UNION ALL
SELECT 'fact_order_item', COUNT(*) FROM fact_order_item
UNION ALL
SELECT 'fact_review', COUNT(*) FROM fact_review;

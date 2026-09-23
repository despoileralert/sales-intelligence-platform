-- Raw data validation checks for the Olist staging tables.
-- Run this after sql/dml/load_raw_data.sql and before sql/dml/transform_data.sql.

USE sales_intelligence;

-- ---------------------------------------------------------------------------
-- Row counts
-- ---------------------------------------------------------------------------

SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count FROM raw_customers
UNION ALL
SELECT 'raw_geolocation', COUNT(*) FROM raw_geolocation
UNION ALL
SELECT 'raw_orders', COUNT(*) FROM raw_orders
UNION ALL
SELECT 'raw_order_items', COUNT(*) FROM raw_order_items
UNION ALL
SELECT 'raw_order_payments', COUNT(*) FROM raw_order_payments
UNION ALL
SELECT 'raw_order_reviews', COUNT(*) FROM raw_order_reviews
UNION ALL
SELECT 'raw_products', COUNT(*) FROM raw_products
UNION ALL
SELECT 'raw_sellers', COUNT(*) FROM raw_sellers
UNION ALL
SELECT 'raw_product_category_translation', COUNT(*) FROM raw_product_category_translation;

-- ---------------------------------------------------------------------------
-- Required key checks
-- ---------------------------------------------------------------------------

SELECT 'raw_customers.customer_id nulls' AS check_name, COUNT(*) AS failed_rows
FROM raw_customers
WHERE customer_id IS NULL OR customer_id = ''
UNION ALL
SELECT 'raw_orders.order_id nulls', COUNT(*)
FROM raw_orders
WHERE order_id IS NULL OR order_id = ''
UNION ALL
SELECT 'raw_order_items.order_id nulls', COUNT(*)
FROM raw_order_items
WHERE order_id IS NULL OR order_id = ''
UNION ALL
SELECT 'raw_order_items.product_id nulls', COUNT(*)
FROM raw_order_items
WHERE product_id IS NULL OR product_id = ''
UNION ALL
SELECT 'raw_order_items.seller_id nulls', COUNT(*)
FROM raw_order_items
WHERE seller_id IS NULL OR seller_id = ''
UNION ALL
SELECT 'raw_order_payments.order_id nulls', COUNT(*)
FROM raw_order_payments
WHERE order_id IS NULL OR order_id = ''
UNION ALL
SELECT 'raw_order_reviews.review_id nulls', COUNT(*)
FROM raw_order_reviews
WHERE review_id IS NULL OR review_id = ''
UNION ALL
SELECT 'raw_products.product_id nulls', COUNT(*)
FROM raw_products
WHERE product_id IS NULL OR product_id = ''
UNION ALL
SELECT 'raw_sellers.seller_id nulls', COUNT(*)
FROM raw_sellers
WHERE seller_id IS NULL OR seller_id = '';

-- ---------------------------------------------------------------------------
-- Duplicate grain checks
-- ---------------------------------------------------------------------------

SELECT 'duplicate raw customer_id' AS check_name, COUNT(*) AS failed_groups
FROM (
    SELECT customer_id
    FROM raw_customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) AS duplicates
UNION ALL
SELECT 'duplicate raw order_id', COUNT(*)
FROM (
    SELECT order_id
    FROM raw_orders
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS duplicates
UNION ALL
SELECT 'duplicate raw order item grain', COUNT(*)
FROM (
    SELECT order_id, order_item_id
    FROM raw_order_items
    GROUP BY order_id, order_item_id
    HAVING COUNT(*) > 1
) AS duplicates
UNION ALL
SELECT 'duplicate raw payment grain', COUNT(*)
FROM (
    SELECT order_id, payment_sequential
    FROM raw_order_payments
    GROUP BY order_id, payment_sequential
    HAVING COUNT(*) > 1
) AS duplicates
UNION ALL
SELECT 'duplicate raw review_id', COUNT(*)
FROM (
    SELECT review_id
    FROM raw_order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS duplicates
UNION ALL
SELECT 'duplicate raw product_id', COUNT(*)
FROM (
    SELECT product_id
    FROM raw_products
    GROUP BY product_id
    HAVING COUNT(*) > 1
) AS duplicates
UNION ALL
SELECT 'duplicate raw seller_id', COUNT(*)
FROM (
    SELECT seller_id
    FROM raw_sellers
    GROUP BY seller_id
    HAVING COUNT(*) > 1
) AS duplicates;

-- ---------------------------------------------------------------------------
-- Relationship checks
-- ---------------------------------------------------------------------------

SELECT 'orders missing customer' AS check_name, COUNT(*) AS failed_rows
FROM raw_orders o
LEFT JOIN raw_customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'order items missing order', COUNT(*)
FROM raw_order_items oi
LEFT JOIN raw_orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'payments missing order', COUNT(*)
FROM raw_order_payments p
LEFT JOIN raw_orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'reviews missing order', COUNT(*)
FROM raw_order_reviews r
LEFT JOIN raw_orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order items missing product', COUNT(*)
FROM raw_order_items oi
LEFT JOIN raw_products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'order items missing seller', COUNT(*)
FROM raw_order_items oi
LEFT JOIN raw_sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- ---------------------------------------------------------------------------
-- Business rule checks
-- ---------------------------------------------------------------------------

SELECT 'negative item price' AS check_name, COUNT(*) AS failed_rows
FROM raw_order_items
WHERE price < 0
UNION ALL
SELECT 'negative freight value', COUNT(*)
FROM raw_order_items
WHERE freight_value < 0
UNION ALL
SELECT 'negative payment value', COUNT(*)
FROM raw_order_payments
WHERE payment_value < 0
UNION ALL
SELECT 'invalid review score', COUNT(*)
FROM raw_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5
UNION ALL
SELECT 'delivered before purchase', COUNT(*)
FROM raw_orders
WHERE order_delivered_customer_date IS NOT NULL
    AND order_delivered_customer_date < order_purchase_timestamp
UNION ALL
SELECT 'approved before purchase', COUNT(*)
FROM raw_orders
WHERE order_approved_at IS NOT NULL
    AND order_approved_at < order_purchase_timestamp;

-- ---------------------------------------------------------------------------
-- Datetime hygiene checks
-- ---------------------------------------------------------------------------

SELECT 'zero review creation date' AS check_name, COUNT(*) AS failed_rows
FROM raw_order_reviews
WHERE CAST(review_creation_date AS CHAR) = '0000-00-00 00:00:00'
UNION ALL
SELECT 'zero review answer timestamp', COUNT(*)
FROM raw_order_reviews
WHERE CAST(review_answer_timestamp AS CHAR) = '0000-00-00 00:00:00'
UNION ALL
SELECT 'missing review creation date', COUNT(*)
FROM raw_order_reviews
WHERE review_creation_date IS NULL
UNION ALL
SELECT 'missing review answer timestamp', COUNT(*)
FROM raw_order_reviews
WHERE review_answer_timestamp IS NULL;

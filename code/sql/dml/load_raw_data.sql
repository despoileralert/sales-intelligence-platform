-- Olist customers dataset
LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_customers_dataset.csv'
INTO TABLE raw_customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state);

-- Order information dataset
LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_orders_dataset.csv'
INTO TABLE raw_orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp,
 @order_approved_at, @order_delivered_carrier_date,
 @order_delivered_customer_date, order_estimated_delivery_date)
SET
 order_approved_at = NULLIF(@order_approved_at, ''),
 order_delivered_carrier_date = NULLIF(@order_delivered_carrier_date, ''),
 order_delivered_customer_date = NULLIF(@order_delivered_customer_date, '');

-- Geolocation dataset
LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_geolocation_dataset.csv'
INTO TABLE raw_geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state);

-- Order items dataset 
LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_order_items_dataset.csv'
INTO TABLE raw_order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value);

LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_order_payments_dataset.csv'
INTO TABLE raw_order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_sequential, payment_type, payment_installments, payment_value);

LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_order_reviews_dataset.csv'
INTO TABLE raw_order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, review_comment_title, review_comment_message,
 @review_creation_date, @review_answer_timestamp)
SET
 review_creation_date = NULLIF(NULLIF(@review_creation_date, ''), '0000-00-00 00:00:00'),
 review_answer_timestamp = NULLIF(NULLIF(@review_answer_timestamp, ''), '0000-00-00 00:00:00');

LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_products_dataset.csv'
INTO TABLE raw_products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm);

LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/olist_sellers_dataset.csv'
INTO TABLE raw_sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

LOAD DATA LOCAL INFILE 'C:/sales-intelligence-platform/data/raw/product_category_name_translation.csv'
INTO TABLE raw_product_category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_category_name, product_category_name_english);

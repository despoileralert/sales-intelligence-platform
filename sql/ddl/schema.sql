-- Active: 1782354710076@@127.0.0.1@3306@sales_intelligence
-- Active: 1782354710076@@127.0.0.1@3306@mysql
-- Sales Intelligence Platform - MySQL analytical schema
-- Source: Olist ecommerce dataset
-- Target: MySQL 8.0+

CREATE DATABASE IF NOT EXISTS sales_intelligence;
USE sales_intelligence;

-- ---------------------------------------------------------------------------
-- Raw staging tables
-- ---------------------------------------------------------------------------
-- These tables mirror the CSV files as closely as possible. They are useful for
-- loading raw data first, then transforming into the analytical star schema.

CREATE TABLE IF NOT EXISTS raw_customers (
    customer_id CHAR(32) NOT NULL,
    customer_unique_id CHAR(32) NOT NULL,
    customer_zip_code_prefix INT NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state CHAR(2) NOT NULL,
    PRIMARY KEY (customer_id),
    INDEX idx_raw_customers_unique_id (customer_unique_id),
    INDEX idx_raw_customers_state (customer_state)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_geolocation (
    geolocation_zip_code_prefix INT NOT NULL,
    geolocation_lat DECIMAL(10, 7) NOT NULL,
    geolocation_lng DECIMAL(10, 7) NOT NULL,
    geolocation_city VARCHAR(100) NOT NULL,
    geolocation_state CHAR(2) NOT NULL,
    INDEX idx_raw_geolocation_zip (geolocation_zip_code_prefix),
    INDEX idx_raw_geolocation_state (geolocation_state)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_orders (
    order_id CHAR(32) NOT NULL,
    customer_id CHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NOT NULL,
    PRIMARY KEY (order_id),
    INDEX idx_raw_orders_customer_id (customer_id),
    INDEX idx_raw_orders_purchase_ts (order_purchase_timestamp),
    INDEX idx_raw_orders_status (order_status),
    CONSTRAINT fk_raw_orders_customer
        FOREIGN KEY (customer_id) REFERENCES raw_customers (customer_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_order_items (
    order_id CHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    product_id CHAR(32) NOT NULL,
    seller_id CHAR(32) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(12, 2) NOT NULL,
    freight_value DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_raw_order_items_product_id (product_id),
    INDEX idx_raw_order_items_seller_id (seller_id),
    CONSTRAINT chk_raw_order_items_price_nonnegative
        CHECK (price >= 0),
    CONSTRAINT chk_raw_order_items_freight_nonnegative
        CHECK (freight_value >= 0),
    CONSTRAINT fk_raw_order_items_order
        FOREIGN KEY (order_id) REFERENCES raw_orders (order_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_order_payments (
    order_id CHAR(32) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(30) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    INDEX idx_raw_order_payments_type (payment_type),
    CONSTRAINT chk_raw_order_payments_installments_nonnegative
        CHECK (payment_installments >= 0),
    CONSTRAINT chk_raw_order_payments_value_nonnegative
        CHECK (payment_value >= 0),
    CONSTRAINT fk_raw_order_payments_order
        FOREIGN KEY (order_id) REFERENCES raw_orders (order_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_order_reviews (
    review_id CHAR(32) NOT NULL,
    order_id CHAR(32) NOT NULL,
    review_score TINYINT NOT NULL,
    review_comment_title TEXT NULL,
    review_comment_message TEXT NULL,
    review_creation_date DATETIME NULL,
    review_answer_timestamp DATETIME NULL,
    PRIMARY KEY (review_id),
    INDEX idx_raw_order_reviews_order_id (order_id),
    INDEX idx_raw_order_reviews_score (review_score),
    CONSTRAINT chk_raw_order_reviews_score_range
        CHECK (review_score BETWEEN 1 AND 5),
    CONSTRAINT fk_raw_order_reviews_order
        FOREIGN KEY (order_id) REFERENCES raw_orders (order_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_products (
    product_id CHAR(32) NOT NULL,
    product_category_name VARCHAR(100) NULL,
    product_name_lenght DECIMAL(8, 2) NULL,
    product_description_lenght DECIMAL(8, 2) NULL,
    product_photos_qty DECIMAL(8, 2) NULL,
    product_weight_g DECIMAL(12, 2) NULL,
    product_length_cm DECIMAL(12, 2) NULL,
    product_height_cm DECIMAL(12, 2) NULL,
    product_width_cm DECIMAL(12, 2) NULL,
    PRIMARY KEY (product_id),
    INDEX idx_raw_products_category (product_category_name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_sellers (
    seller_id CHAR(32) NOT NULL,
    seller_zip_code_prefix INT NOT NULL,
    seller_city VARCHAR(100) NOT NULL,
    seller_state CHAR(2) NOT NULL,
    PRIMARY KEY (seller_id),
    INDEX idx_raw_sellers_state (seller_state)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS raw_product_category_translation (
    product_category_name VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100) NOT NULL,
    PRIMARY KEY (product_category_name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- ---------------------------------------------------------------------------
-- Analytical dimensions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_date (
    date_key INT NOT NULL,
    full_date DATE NOT NULL,
    year_number SMALLINT NOT NULL,
    quarter_number TINYINT NOT NULL,
    month_number TINYINT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    week_number TINYINT NOT NULL,
    day_of_month TINYINT NOT NULL,
    day_of_week TINYINT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    PRIMARY KEY (date_key),
    UNIQUE KEY uq_dim_date_full_date (full_date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS dim_customer (
    customer_unique_id CHAR(32) NOT NULL,
    first_customer_id CHAR(32) NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state CHAR(2) NOT NULL,
    customer_zip_code_prefix INT NOT NULL,
    first_order_date DATETIME NULL,
    last_order_date DATETIME NULL,
    total_orders INT NOT NULL DEFAULT 0,
    PRIMARY KEY (customer_unique_id),
    INDEX idx_dim_customer_state (customer_state),
    INDEX idx_dim_customer_first_customer_id (first_customer_id),
    CONSTRAINT chk_dim_customer_total_orders_nonnegative
        CHECK (total_orders >= 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS dim_product (
    product_id CHAR(32) NOT NULL,
    product_category_name VARCHAR(100) NOT NULL DEFAULT 'unknown',
    product_category_name_english VARCHAR(100) NOT NULL DEFAULT 'unknown',
    product_name_length DECIMAL(8, 2) NULL,
    product_description_length DECIMAL(8, 2) NULL,
    product_photos_qty DECIMAL(8, 2) NULL,
    product_weight_g DECIMAL(12, 2) NULL,
    product_volume_cm3 DECIMAL(18, 2) NULL,
    PRIMARY KEY (product_id),
    INDEX idx_dim_product_category_en (product_category_name_english)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS dim_seller (
    seller_id CHAR(32) NOT NULL,
    seller_city VARCHAR(100) NOT NULL,
    seller_state CHAR(2) NOT NULL,
    seller_zip_code_prefix INT NOT NULL,
    PRIMARY KEY (seller_id),
    INDEX idx_dim_seller_state (seller_state)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- ---------------------------------------------------------------------------
-- Analytical facts
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fact_order (
    order_id CHAR(32) NOT NULL,
    customer_id CHAR(32) NOT NULL,
    customer_unique_id CHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NOT NULL,
    purchase_date_key INT NOT NULL,
    approved_date_key INT NULL,
    delivered_carrier_date_key INT NULL,
    delivered_customer_date_key INT NULL,
    estimated_delivery_date_key INT NOT NULL,
    payment_value DECIMAL(12, 2) NOT NULL DEFAULT 0,
    merchandise_value DECIMAL(12, 2) NOT NULL DEFAULT 0,
    freight_value DECIMAL(12, 2) NOT NULL DEFAULT 0,
    item_count INT NOT NULL DEFAULT 0,
    seller_count INT NOT NULL DEFAULT 0,
    approval_days DECIMAL(10, 2) NULL,
    carrier_handling_days DECIMAL(10, 2) NULL,
    delivery_days DECIMAL(10, 2) NULL,
    estimated_delivery_days DECIMAL(10, 2) NULL,
    late_delivery_flag BOOLEAN NULL,
    PRIMARY KEY (order_id),
    INDEX idx_fact_order_customer_unique_id (customer_unique_id),
    INDEX idx_fact_order_purchase_date_key (purchase_date_key),
    INDEX idx_fact_order_status (order_status),
    INDEX idx_fact_order_late_delivery (late_delivery_flag),
    CONSTRAINT chk_fact_order_payment_nonnegative
        CHECK (payment_value >= 0),
    CONSTRAINT chk_fact_order_merchandise_nonnegative
        CHECK (merchandise_value >= 0),
    CONSTRAINT chk_fact_order_freight_nonnegative
        CHECK (freight_value >= 0),
    CONSTRAINT chk_fact_order_item_count_nonnegative
        CHECK (item_count >= 0),
    CONSTRAINT chk_fact_order_seller_count_nonnegative
        CHECK (seller_count >= 0),
    CONSTRAINT fk_fact_order_customer
        FOREIGN KEY (customer_unique_id) REFERENCES dim_customer (customer_unique_id),
    CONSTRAINT fk_fact_order_purchase_date
        FOREIGN KEY (purchase_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fact_order_approved_date
        FOREIGN KEY (approved_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fact_order_delivered_carrier_date
        FOREIGN KEY (delivered_carrier_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fact_order_delivered_customer_date
        FOREIGN KEY (delivered_customer_date_key) REFERENCES dim_date (date_key),
    CONSTRAINT fk_fact_order_estimated_delivery_date
        FOREIGN KEY (estimated_delivery_date_key) REFERENCES dim_date (date_key)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fact_order_item (
    order_id CHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    product_id CHAR(32) NOT NULL,
    seller_id CHAR(32) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    shipping_limit_date_key INT NOT NULL,
    price DECIMAL(12, 2) NOT NULL,
    freight_value DECIMAL(12, 2) NOT NULL,
    line_total_value DECIMAL(12, 2) NOT NULL,
    freight_rate DECIMAL(10, 4) NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_fact_order_item_product_id (product_id),
    INDEX idx_fact_order_item_seller_id (seller_id),
    INDEX idx_fact_order_item_shipping_limit_date_key (shipping_limit_date_key),
    CONSTRAINT chk_fact_order_item_price_nonnegative
        CHECK (price >= 0),
    CONSTRAINT chk_fact_order_item_freight_nonnegative
        CHECK (freight_value >= 0),
    CONSTRAINT chk_fact_order_item_line_total_nonnegative
        CHECK (line_total_value >= 0),
    CONSTRAINT fk_fact_order_item_order
        FOREIGN KEY (order_id) REFERENCES fact_order (order_id),
    CONSTRAINT fk_fact_order_item_product
        FOREIGN KEY (product_id) REFERENCES dim_product (product_id),
    CONSTRAINT fk_fact_order_item_seller
        FOREIGN KEY (seller_id) REFERENCES dim_seller (seller_id),
    CONSTRAINT fk_fact_order_item_shipping_limit_date
        FOREIGN KEY (shipping_limit_date_key) REFERENCES dim_date (date_key)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS fact_review (
    review_id CHAR(32) NOT NULL,
    order_id CHAR(32) NOT NULL,
    review_score TINYINT NOT NULL,
    review_comment_title TEXT NULL,
    review_comment_message TEXT NULL,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NULL,
    review_creation_date_key INT NOT NULL,
    review_response_days DECIMAL(10, 2) NULL,
    has_review_comment BOOLEAN NOT NULL,
    is_negative_review BOOLEAN NOT NULL,
    is_positive_review BOOLEAN NOT NULL,
    PRIMARY KEY (review_id),
    INDEX idx_fact_review_order_id (order_id),
    INDEX idx_fact_review_score (review_score),
    INDEX idx_fact_review_creation_date_key (review_creation_date_key),
    CONSTRAINT chk_fact_review_score_range
        CHECK (review_score BETWEEN 1 AND 5),
    CONSTRAINT fk_fact_review_order
        FOREIGN KEY (order_id) REFERENCES fact_order (order_id),
    CONSTRAINT fk_fact_review_creation_date
        FOREIGN KEY (review_creation_date_key) REFERENCES dim_date (date_key)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

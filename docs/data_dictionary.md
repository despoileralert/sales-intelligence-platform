# Data Dictionary

This document describes the raw datasets used by the sales intelligence platform and the recommended analytical entities derived from them.

Source data location: `data/raw`

## Raw Data Overview

| Dataset | File | Grain | Primary Key | Notes |
| --- | --- | --- | --- | --- |
| Customers | `olist_customers_dataset.csv` | One row per order-level customer record | `customer_id` | Links orders to customer geography and stable customer identity. |
| Geolocation | `olist_geolocation_dataset.csv` | One row per geolocation observation by zip prefix | None | Contains duplicate zip/city/state coordinates; aggregate before joining. |
| Orders | `olist_orders_dataset.csv` | One row per order | `order_id` | Central order lifecycle table. |
| Order Items | `olist_order_items_dataset.csv` | One row per item within an order | `order_id`, `order_item_id` | Connects orders, products, sellers, price, and freight. |
| Order Payments | `olist_order_payments_dataset.csv` | One row per payment event | `order_id`, `payment_sequential` | Orders can have multiple payment rows. |
| Order Reviews | `olist_order_reviews_dataset.csv` | One row per review | `review_id` | Reviews are linked to orders. Some orders may have multiple review records. |
| Products | `olist_products_dataset.csv` | One row per product | `product_id` | Product category and physical product attributes. |
| Sellers | `olist_sellers_dataset.csv` | One row per seller | `seller_id` | Seller location attributes. |
| Category Translation | `product_category_name_translation.csv` | One row per product category | `product_category_name` | Portuguese-to-English category mapping. |

## Customers

File: `data/raw/olist_customers_dataset.csv`

Description: This dataset has information about the customer and its location. Use it to identify unique customers in the orders dataset and to find the orders delivery location. At our system each order is assigned to a unique customer_id. This means that the same customer will get different ids for different orders. The purpose of having a customer_unique_id on the dataset is to allow you to identify customers that made repurchases at the store. Otherwise you would find that each order had a different customer associated with.

Grain: one row per customer record associated with an order.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `customer_id` | string | Order-level customer identifier. | No | Primary key; joins to `orders.customer_id`. |
| `customer_unique_id` | string | Stable customer identifier across multiple orders. | No | Use for repeat customer and retention analysis. |
| `customer_zip_code_prefix` | integer | Customer zip code prefix. | No | Can join to aggregated geolocation data. |
| `customer_city` | string | Customer city. | No | Geography dimension attribute. |
| `customer_state` | string | Customer state abbreviation. | No | Geography dimension attribute. |

## Geolocation

File: `data/raw/olist_geolocation_dataset.csv`

Description: This dataset has information Brazilian zip codes and its lat/lng coordinates. Use it to plot maps and find distances between sellers and customers.

Grain: one row per geolocation observation by zip code prefix.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `geolocation_zip_code_prefix` | integer | Zip code prefix. | No | Join key to customer or seller zip prefixes after aggregation. |
| `geolocation_lat` | float | Latitude. | No | Mapping and distance analysis. |
| `geolocation_lng` | float | Longitude. | No | Mapping and distance analysis. |
| `geolocation_city` | string | City associated with zip prefix. | No | Geography attribute. |
| `geolocation_state` | string | State abbreviation. | No | Geography attribute. |

Quality note: this dataset contains many duplicate rows and multiple coordinates per zip prefix. For dimensional modeling, aggregate by `geolocation_zip_code_prefix`, usually with median latitude and longitude.

## Orders

File: `data/raw/olist_orders_dataset.csv`

Description: This is the core dataset. From each order you might find all other information.

Grain: one row per order.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `order_id` | string | Unique order identifier. | No | Primary key; joins to items, payments, and reviews. |
| `customer_id` | string | Order-level customer identifier. | No | Foreign key to `customers.customer_id`. |
| `order_status` | string | Current or final order status. | No | Used for fulfillment funnel analysis. |
| `order_purchase_timestamp` | datetime | Date/time when the order was placed. | No | Main order date for time-series reporting. |
| `order_approved_at` | datetime | Date/time when payment/order was approved. | Yes | Approval latency analysis. |
| `order_delivered_carrier_date` | datetime | Date/time when the order was handed to carrier. | Yes | Fulfillment latency analysis. |
| `order_delivered_customer_date` | datetime | Date/time when the customer received the order. | Yes | Delivery duration and late delivery analysis. |
| `order_estimated_delivery_date` | datetime | Estimated delivery date provided to customer. | No | Compare against actual delivery date. |

Derived fields:

| Field | Formula | Description |
| --- | --- | --- |
| `approval_days` | `order_approved_at - order_purchase_timestamp` | Time from purchase to approval. |
| `carrier_handling_days` | `order_delivered_carrier_date - order_approved_at` | Time from approval to carrier handoff. |
| `delivery_days` | `order_delivered_customer_date - order_purchase_timestamp` | Total days from purchase to customer delivery. |
| `estimated_delivery_days` | `order_estimated_delivery_date - order_purchase_timestamp` | Promised delivery duration. |
| `late_delivery_flag` | `order_delivered_customer_date > order_estimated_delivery_date` | Indicates whether delivery missed the estimate. |

## Order Items

File: `data/raw/olist_order_items_dataset.csv`

Description: This dataset includes data about the items purchased within each order. Example: The order_id = 00143d0f86d6fbd9f9b38ab440ac16f5 has 3 items (same product). Each item has the freight calculated accordingly to its measures and weight. To get the total freight value for each order you just have to sum.

Grain: one row per item within an order.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `order_id` | string | Order identifier. | No | Foreign key to `orders.order_id`. |
| `order_item_id` | integer | Item sequence number within an order. | No | Composite key with `order_id`. |
| `product_id` | string | Product identifier. | No | Foreign key to `products.product_id`. |
| `seller_id` | string | Seller identifier. | No | Foreign key to `sellers.seller_id`. |
| `shipping_limit_date` | datetime | Seller shipping deadline. | No | Seller fulfillment SLA analysis. |
| `price` | float | Item merchandise price. | No | Revenue analysis; excludes freight. |
| `freight_value` | float | Freight/shipping value for the item. | No | Logistics cost and customer charge analysis. |

Derived fields:

| Field | Formula | Description |
| --- | --- | --- |
| `line_total_value` | `price + freight_value` | Total item value including freight. |
| `freight_rate` | `freight_value / price` | Freight as a percentage of merchandise price. |

## Order Payments

File: `data/raw/olist_order_payments_dataset.csv`

Description: This dataset includes data about the orders payment options.

Grain: one row per payment event for an order.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `order_id` | string | Order identifier. | No | Foreign key to `orders.order_id`. |
| `payment_sequential` | integer | Payment sequence for orders with multiple payments. | No | Composite key with `order_id`. |
| `payment_type` | string | Payment method used. | No | Payment mix analysis. |
| `payment_installments` | integer | Number of installments. | No | Installment behavior analysis. |
| `payment_value` | float | Payment amount. | No | Gross paid value. |

Transformation note: aggregate payments to order level before joining to `orders` if building a one-row-per-order fact table.

## Order Reviews

File: `data/raw/olist_order_reviews_dataset.csv`

Description: This dataset includes data about the reviews made by the customers. After a customer purchases the product from Olist Store a seller gets notified to fulfill that order. Once the customer receives the product, or the estimated delivery date is due, the customer gets a satisfaction survey by email where he can give a note for the purchase experience and write down some comments.

Grain: one row per review.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `review_id` | string | Review identifier. | No | Review key. |
| `order_id` | string | Order identifier. | No | Foreign key to `orders.order_id`. |
| `review_score` | integer | Customer rating from 1 to 5. | No | Customer satisfaction metric. |
| `review_comment_title` | string | Review title. | Yes | Text analysis; high missingness expected. |
| `review_comment_message` | string | Review body. | Yes | Text analysis; high missingness expected. |
| `review_creation_date` | datetime | Date review was created. | No | Review timing analysis. |
| `review_answer_timestamp` | datetime | Date/time review was answered. | No | Response time analysis. |

Derived fields:

| Field | Formula | Description |
| --- | --- | --- |
| `review_response_days` | `review_answer_timestamp - review_creation_date` | Time to answer review. |
| `has_review_comment` | `review_comment_message is not null` | Indicates whether customer wrote a text review. |
| `is_negative_review` | `review_score <= 2` | Useful for customer experience monitoring. |
| `is_positive_review` | `review_score >= 4` | Useful for customer satisfaction reporting. |

## Products

File: `data/raw/olist_products_dataset.csv`

Description: This dataset includes data about the products sold by Olist.

Grain: one row per product.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `product_id` | string | Product identifier. | No | Primary key; joins to `order_items.product_id`. |
| `product_category_name` | string | Product category in Portuguese. | Yes | Join to category translation. |
| `product_name_lenght` | float | Length of product name text. | Yes | Original column name contains typo. |
| `product_description_lenght` | float | Length of product description text. | Yes | Original column name contains typo. |
| `product_photos_qty` | float | Number of product photos. | Yes | Product content completeness metric. |
| `product_weight_g` | float | Product weight in grams. | Yes | Shipping and logistics analysis. |
| `product_length_cm` | float | Product length in centimeters. | Yes | Shipping and logistics analysis. |
| `product_height_cm` | float | Product height in centimeters. | Yes | Shipping and logistics analysis. |
| `product_width_cm` | float | Product width in centimeters. | Yes | Shipping and logistics analysis. |

Recommended renamed fields:

| Original Column | Recommended Column |
| --- | --- |
| `product_name_lenght` | `product_name_length` |
| `product_description_lenght` | `product_description_length` |

Derived fields:

| Field | Formula | Description |
| --- | --- | --- |
| `product_volume_cm3` | `product_length_cm * product_height_cm * product_width_cm` | Approximate product volume. |
| `product_category_name_english` | translation lookup | English category for reporting. |

## Sellers

File: `data/raw/olist_sellers_dataset.csv`

Description: This dataset includes data about the sellers that fulfilled orders made at Olist. Use it to find the seller location and to identify which seller fulfilled each product.  

Grain: one row per seller.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `seller_id` | string | Seller identifier. | No | Primary key; joins to `order_items.seller_id`. |
| `seller_zip_code_prefix` | integer | Seller zip code prefix. | No | Can join to aggregated geolocation data. |
| `seller_city` | string | Seller city. | No | Seller geography attribute. |
| `seller_state` | string | Seller state abbreviation. | No | Seller geography attribute. |

## Category Translation

File: `data/raw/product_category_name_translation.csv`

Description: Translates the product_category_name to english.

Grain: one row per product category.

| Column | Type | Description | Nullable | Key / Usage |
| --- | --- | --- | --- | --- |
| `product_category_name` | string | Product category in Portuguese. | No | Primary key; joins to `products.product_category_name`. |
| `product_category_name_english` | string | English category name. | No | Preferred reporting label. |

## Analytics Layer and Database Schema

### `dim_customer`

Grain: one row per `customer_unique_id`.

Recommended fields:

| Field | Source | Description |
| --- | --- | --- |
| `customer_unique_id` | Customers | Stable customer key. |
| `first_customer_id` | Customers | Representative order-level customer ID. |
| `customer_city` | Customers | Most recent or most common customer city. |
| `customer_state` | Customers | Most recent or most common customer state. |
| `customer_zip_code_prefix` | Customers | Most recent or most common zip prefix. |
| `first_order_date` | Orders | First purchase timestamp. |
| `last_order_date` | Orders | Most recent purchase timestamp. |
| `total_orders` | Orders | Count of orders for the customer. |

### `dim_product`

Grain: one row per `product_id`.

Recommended fields:

| Field | Source | Description |
| --- | --- | --- |
| `product_id` | Products | Product key. |
| `product_category_name` | Products | Original category. |
| `product_category_name_english` | Category Translation | English category. |
| `product_name_length` | Products | Corrected product name length field. |
| `product_description_length` | Products | Corrected description length field. |
| `product_photos_qty` | Products | Number of photos. |
| `product_weight_g` | Products | Product weight. |
| `product_volume_cm3` | Products | Derived product volume. |

### `dim_seller`

Grain: one row per `seller_id`.

Recommended fields:

| Field | Source | Description |
| --- | --- | --- |
| `seller_id` | Sellers | Seller key. |
| `seller_city` | Sellers | Seller city. |
| `seller_state` | Sellers | Seller state. |
| `seller_zip_code_prefix` | Sellers | Seller zip prefix. |

### `fact_order`

Grain: one row per `order_id`.

Recommended fields:

| Field | Source | Description |
| --- | --- | --- |
| `order_id` | Orders | Order key. |
| `customer_id` | Orders | Order-level customer key. |
| `customer_unique_id` | Customers | Stable customer key. |
| `order_status` | Orders | Order status. |
| `order_purchase_timestamp` | Orders | Purchase timestamp. |
| `order_approved_at` | Orders | Approval timestamp. |
| `order_delivered_carrier_date` | Orders | Carrier handoff timestamp. |
| `order_delivered_customer_date` | Orders | Delivery timestamp. |
| `order_estimated_delivery_date` | Orders | Estimated delivery date. |
| `payment_value` | Payments | Sum of payments for the order. |
| `merchandise_value` | Order Items | Sum of item prices. |
| `freight_value` | Order Items | Sum of freight values. |
| `item_count` | Order Items | Count of order item rows. |
| `seller_count` | Order Items | Distinct sellers in the order. |
| `delivery_days` | Derived | Purchase-to-delivery duration. |
| `late_delivery_flag` | Derived | Whether delivery missed estimated date. |

### `fact_order_item`

Grain: one row per `order_id` and `order_item_id`.

Recommended fields:

| Field | Source | Description |
| --- | --- | --- |
| `order_id` | Order Items | Order key. |
| `order_item_id` | Order Items | Item sequence within order. |
| `product_id` | Order Items | Product key. |
| `seller_id` | Order Items | Seller key. |
| `shipping_limit_date` | Order Items | Seller shipping deadline. |
| `price` | Order Items | Item merchandise price. |
| `freight_value` | Order Items | Item freight value. |
| `line_total_value` | Derived | Price plus freight. |

### `fact_review`

Grain: one row per review.

Recommended fields:

| Field | Source | Description |
| --- | --- | --- |
| `review_id` | Reviews | Review key. |
| `order_id` | Reviews | Order key. |
| `review_score` | Reviews | Rating from 1 to 5. |
| `review_comment_title` | Reviews | Review title. |
| `review_comment_message` | Reviews | Review text. |
| `review_creation_date` | Reviews | Review creation date. |
| `review_answer_timestamp` | Reviews | Review answer timestamp. |
| `review_response_days` | Derived | Days from creation to answer. |
| `has_review_comment` | Derived | Whether review has text. |

## Data Quality Rules

Recommended validation checks:

| Rule | Severity | Description |
| --- | --- | --- |
| Required files exist | Error | All expected raw CSV files must be present before ingestion. |
| Required columns exist | Error | Each file must contain the expected columns listed above. |
| Primary keys are non-null | Error | Primary key fields must not be null. |
| Order IDs are unique in orders | Error | `orders.order_id` should be unique. |
| Customer IDs join from orders to customers | Error | Every `orders.customer_id` should exist in customers. |
| Order items join to orders | Warning | Every item should reference a valid order. |
| Payments join to orders | Warning | Every payment should reference a valid order. |
| Reviews join to orders | Warning | Every review should reference a valid order. |
| Product IDs join from items to products | Warning | Every order item should reference a known product. |
| Seller IDs join from items to sellers | Warning | Every order item should reference a known seller. |
| Dates parse successfully | Error | Timestamp fields should parse to valid datetimes. |
| Delivered date is after purchase date | Warning | Delivered orders should not have delivery before purchase. |
| Negative prices or freight values | Error | `price`, `freight_value`, and `payment_value` should not be negative. |
| Missing review comments | Info | Missing review title/message is expected and should not fail ingestion. |
| Missing product categories | Warning | Missing product categories should be preserved as `unknown`, not dropped. |

## Business Metric Definitions

| Metric | Definition |
| --- | --- |
| Orders | Count of distinct `order_id`. |
| Customers | Count of distinct `customer_unique_id`. |
| Sellers | Count of distinct `seller_id`. |
| Products | Count of distinct `product_id`. |
| Merchandise Revenue | Sum of `order_items.price`. |
| Freight Value | Sum of `order_items.freight_value`. |
| Payment Value | Sum of `order_payments.payment_value`. |
| Average Order Value | Total payment value divided by distinct paid orders. |
| Items per Order | Count of order item rows divided by distinct orders. |
| Late Delivery Rate | Delivered orders with `order_delivered_customer_date > order_estimated_delivery_date` divided by delivered orders. |
| Median Delivery Days | Median days between purchase timestamp and delivered customer date. |
| Average Review Score | Average of `review_score`. |

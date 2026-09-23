# Database Schema

Star schema in the `sales_intelligence` database, built by `code/sql/ddl/schema.sql` and populated by `code/sql/dml/transform_data.sql`.

`dim_date` is a role-playing dimension: `fact_order` joins to it five times (purchase, approval, carrier handoff, customer delivery, estimated delivery). Customer attributes reach item-level analysis through `fact_order`, not directly.

```mermaid
erDiagram
    DIM_CUSTOMER ||--o{ FACT_ORDER : places
    DIM_DATE ||--o{ FACT_ORDER : "purchase / delivery dates"
    FACT_ORDER ||--o{ FACT_ORDER_ITEM : contains
    FACT_ORDER ||--o{ FACT_REVIEW : receives
    DIM_PRODUCT ||--o{ FACT_ORDER_ITEM : "sold as"
    DIM_SELLER ||--o{ FACT_ORDER_ITEM : fulfills
    DIM_DATE ||--o{ FACT_ORDER_ITEM : "shipping limit"
    DIM_DATE ||--o{ FACT_REVIEW : "created on"

    FACT_ORDER {
        char order_id PK
        char customer_unique_id FK
        varchar order_status
        int purchase_date_key FK
        int approved_date_key FK
        int delivered_carrier_date_key FK
        int delivered_customer_date_key FK
        int estimated_delivery_date_key FK
        decimal payment_value
        decimal merchandise_value
        decimal freight_value
        int item_count
        int seller_count
        decimal delivery_days
        decimal estimated_delivery_days
        boolean late_delivery_flag
    }

    FACT_ORDER_ITEM {
        char order_id PK
        int order_item_id PK
        char product_id FK
        char seller_id FK
        datetime shipping_limit_date
        int shipping_limit_date_key FK
        decimal price
        decimal freight_value
        decimal line_total_value
        decimal freight_rate
    }

    FACT_REVIEW {
        char review_id PK
        char order_id FK
        tinyint review_score
        int review_creation_date_key FK
        decimal review_response_days
        boolean has_review_comment
        boolean is_negative_review
    }
```

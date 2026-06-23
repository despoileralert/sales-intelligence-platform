# Business Requirements

## 1. Objective

The sales intelligence platform provides business users with a clear view of ecommerce performance across revenue, customers, operations, and customer experience.

The platform should help stakeholders monitor growth, identify operational issues, understand customer behavior, and track satisfaction.

## 2. Business Users

Primary users:

- Sales managers
- Operations managers
- Customer experience teams
- Business analysts
- Executive stakeholders

## 3. Reporting Areas

The platform will track four main business areas:

| Area | Purpose |
| --- | --- |
| Financial | Understand revenue performance and order value. |
| Customer | Track customer base size and repeat purchasing behavior. |
| Operations | Monitor delivery speed and fulfillment reliability. |
| Experience | Measure customer satisfaction through reviews. |

## 4. Key Business Metrics

### Financial Metrics

| Metric | Definition | Formula | Business Purpose |
| --- | --- | --- | --- |
| Total Revenue | Total sales value generated from orders. | `SUM(payment_value)` or `SUM(price + freight_value)` depending on reporting definition. | Measures overall business performance. |
| Revenue Growth % | Percentage change in revenue over time. | `(Current Period Revenue - Previous Period Revenue) / Previous Period Revenue * 100` | Shows whether revenue is growing or declining. |
| Orders | Total number of unique orders. | `COUNT(DISTINCT order_id)` | Measures sales volume. |
| Average Order Value | Average revenue per order. | `Total Revenue / Orders` | Shows how much customers spend per order. |

### Customer Metrics

| Metric | Definition | Formula | Business Purpose |
| --- | --- | --- | --- |
| Total Customers | Number of unique customers. | `COUNT(DISTINCT customer_unique_id)` | Measures size of customer base. |
| Repeat Purchase Rate | Percentage of customers with more than one order. | `Customers with 2+ Orders / Total Customers * 100` | Measures customer retention and loyalty. |

### Operations Metrics

| Metric | Definition | Formula | Business Purpose |
| --- | --- | --- | --- |
| Average Delivery Time | Average number of days from purchase to delivery. | `AVG(order_delivered_customer_date - order_purchase_timestamp)` | Measures fulfillment speed. |
| Late Delivery Rate | Percentage of delivered orders that arrived after estimated delivery date. | `Late Delivered Orders / Delivered Orders * 100` | Measures delivery reliability. |

### Experience Metrics

| Metric | Definition | Formula | Business Purpose |
| --- | --- | --- | --- |
| Average Review Score | Average customer review rating. | `AVG(review_score)` | Measures customer satisfaction. |

## 5. Dashboard Requirements

The dashboard should include:

- KPI cards for each core metric.
- Monthly revenue and order trend.
- Revenue growth comparison by month.
- Customer growth and repeat purchase trend.
- Average delivery time trend.
- Late delivery rate trend.
- Review score distribution.
- Filters for date range, customer state, product category, seller state, and order status.

## 6. Data Requirements

Required datasets:

| Dataset | Purpose |
| --- | --- |
| Orders | Order dates, statuses, delivery dates, and customer links. |
| Order Items | Product, seller, price, and freight values. |
| Payments | Payment value and payment method. |
| Customers | Unique customer IDs and geography. |
| Reviews | Review scores and customer feedback. |
| Products | Product category information. |
| Sellers | Seller geography and seller identifiers. |

## 7. Business Rules

- Revenue should be calculated consistently across all reports.
- Cancelled and unavailable orders should be excluded from revenue unless explicitly analyzed.
- Delivery metrics should only include orders with a valid delivered customer date.
- Late delivery should compare actual customer delivery date against estimated delivery date.
- Repeat purchase rate should use `customer_unique_id`, not `customer_id`.
- Review metrics should only include valid review scores from 1 to 5.

## 8. Success Criteria

The platform is successful if users can:

- Monitor total revenue, growth, order volume, and average order value.
- Identify whether revenue is increasing or declining over time.
- Understand customer acquisition and repeat purchase behavior.
- Detect delivery delays and operational bottlenecks.
- Track customer satisfaction using review scores.
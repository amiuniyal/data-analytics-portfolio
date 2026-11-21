-- UrbanCart business analysis queries
-- Run against data/urbancart.db (SQLite). Results are shown in README.md.

-- Q1. Yearly performance & YoY growth
-- Business question: How did sales, profit and margin change each year?
WITH yearly AS (
    SELECT strftime('%Y', order_date)      AS year,
           COUNT(DISTINCT order_id)        AS orders,
           ROUND(SUM(sales_amount), 0)     AS sales,
           ROUND(SUM(profit), 0)           AS profit
    FROM order_lines
    GROUP BY year
)
SELECT year,
       orders,
       sales,
       profit,
       ROUND(100.0 * profit / sales, 1)                                    AS margin_pct,
       ROUND(100.0 * (sales - LAG(sales) OVER (ORDER BY year))
             / LAG(sales) OVER (ORDER BY year), 1)                         AS yoy_growth_pct
FROM yearly
ORDER BY year;

-- Q2. Category & sub-category performance
-- Business question: Which product lines drive revenue, and which drive profit?
SELECT p.category,
       p.sub_category,
       ROUND(SUM(o.sales_amount), 0)                        AS sales,
       ROUND(SUM(o.profit), 0)                              AS profit,
       ROUND(100.0 * SUM(o.profit) / SUM(o.sales_amount), 1) AS margin_pct,
       RANK() OVER (ORDER BY SUM(o.profit) DESC)            AS profit_rank
FROM order_lines o
JOIN products p ON p.product_id = o.product_id
GROUP BY p.category, p.sub_category
ORDER BY profit DESC;

-- Q3. Top 10 products by profit
-- Business question: Which individual products earn the most?
SELECT p.product_name,
       p.category,
       SUM(o.quantity)                                      AS units_sold,
       ROUND(SUM(o.sales_amount), 0)                        AS sales,
       ROUND(SUM(o.profit), 0)                              AS profit,
       ROUND(100.0 * SUM(o.profit) / SUM(o.sales_amount), 1) AS margin_pct
FROM order_lines o
JOIN products p ON p.product_id = o.product_id
GROUP BY p.product_name, p.category
ORDER BY profit DESC
LIMIT 10;

-- Q4. Regional sales vs target (2025)
-- Business question: Which regions hit their sales targets in 2025?
WITH actuals AS (
    SELECT r.region,
           SUM(o.sales_amount) AS actual_sales
    FROM order_lines o
    JOIN regions r ON r.region_id = o.region_id
    WHERE o.order_date BETWEEN '2025-01-01' AND '2025-12-31'
    GROUP BY r.region
),
targets AS (
    SELECT region, SUM(sales_target) AS target_sales
    FROM sales_targets
    WHERE month_start BETWEEN '2025-01-01' AND '2025-12-31'
    GROUP BY region
)
SELECT a.region,
       ROUND(a.actual_sales, 0)                              AS actual_sales,
       ROUND(t.target_sales, 0)                              AS target_sales,
       ROUND(100.0 * a.actual_sales / t.target_sales, 1)     AS achievement_pct,
       CASE WHEN a.actual_sales >= t.target_sales
            THEN 'Target met' ELSE 'Below target' END        AS status
FROM actuals a
JOIN targets t ON t.region = a.region
ORDER BY achievement_pct DESC;

-- Q5. Customer segment analysis
-- Business question: How do Consumer, Corporate and Small Business customers compare?
SELECT c.segment,
       COUNT(DISTINCT c.customer_id)                                       AS customers,
       COUNT(DISTINCT o.order_id)                                          AS orders,
       ROUND(SUM(o.sales_amount), 0)                                       AS sales,
       ROUND(SUM(o.sales_amount) / COUNT(DISTINCT o.order_id), 0)          AS avg_order_value,
       ROUND(SUM(o.sales_amount) / COUNT(DISTINCT c.customer_id), 0)       AS sales_per_customer
FROM order_lines o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.segment
ORDER BY sales DESC;

-- Q6. Top 10 customers by lifetime value
-- Business question: Who are the most valuable customers?
SELECT c.customer_id,
       c.customer_name,
       c.segment,
       COUNT(DISTINCT o.order_id)        AS orders,
       ROUND(SUM(o.sales_amount), 0)     AS lifetime_sales,
       MIN(o.order_date)                 AS first_order,
       MAX(o.order_date)                 AS last_order
FROM order_lines o
JOIN customers c ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name, c.segment
ORDER BY lifetime_sales DESC
LIMIT 10;

-- Q7. Impact of discounts on profit
-- Business question: Are discounts helping or hurting profitability?
SELECT CASE
           WHEN discount_pct = 0     THEN '0% (no discount)'
           WHEN discount_pct <= 0.10 THEN '1-10%'
           WHEN discount_pct <= 0.15 THEN '11-15%'
           ELSE '16%+'
       END                                                  AS discount_band,
       COUNT(*)                                             AS order_lines,
       ROUND(SUM(sales_amount), 0)                          AS sales,
       ROUND(SUM(profit), 0)                                AS profit,
       ROUND(100.0 * SUM(profit) / SUM(sales_amount), 1)    AS margin_pct,
       SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END)          AS loss_making_lines
FROM order_lines
GROUP BY discount_band
ORDER BY MIN(discount_pct);

-- Q8. Return rate by category
-- Business question: Which categories have the most returns, and how much revenue is at risk?
SELECT p.category,
       COUNT(*)                                                             AS order_lines,
       SUM(CASE WHEN o.returned = 'Yes' THEN 1 ELSE 0 END)                  AS returned_lines,
       ROUND(100.0 * SUM(CASE WHEN o.returned = 'Yes' THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                                 AS return_rate_pct,
       ROUND(SUM(CASE WHEN o.returned = 'Yes' THEN o.sales_amount ELSE 0 END), 0) AS returned_sales
FROM order_lines o
JOIN products p ON p.product_id = o.product_id
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- Q9. Customer retention: repeat buyers
-- Business question: How many customers keep coming back across years?
WITH customer_years AS (
    SELECT customer_id,
           COUNT(DISTINCT strftime('%Y', order_date)) AS active_years,
           COUNT(DISTINCT order_id)                   AS orders
    FROM order_lines
    GROUP BY customer_id
)
SELECT active_years,
       COUNT(*)                                              AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS share_pct,
       ROUND(AVG(orders), 1)                                 AS avg_orders_per_customer
FROM customer_years
GROUP BY active_years
ORDER BY active_years;

-- Q10. Monthly sales with running total (2025)
-- Business question: How did 2025 build up month by month?
WITH monthly AS (
    SELECT strftime('%m', order_date)   AS month,
           ROUND(SUM(sales_amount), 0)  AS sales
    FROM order_lines
    WHERE order_date BETWEEN '2025-01-01' AND '2025-12-31'
    GROUP BY month
)
SELECT month,
       sales,
       SUM(sales) OVER (ORDER BY month)                         AS running_total,
       ROUND(100.0 * sales / SUM(sales) OVER (), 1)             AS share_of_year_pct
FROM monthly
ORDER BY month;

-- Q11. Shipping performance
-- Business question: How fast does each ship mode deliver?
SELECT ship_mode,
       COUNT(DISTINCT order_id)                                        AS orders,
       ROUND(AVG(julianday(ship_date) - julianday(order_date)), 1)     AS avg_days_to_ship,
       MAX(julianday(ship_date) - julianday(order_date))               AS max_days_to_ship
FROM order_lines
GROUP BY ship_mode
ORDER BY avg_days_to_ship;

-- Q12. Sales channel mix by year
-- Business question: Is the business shifting online?
SELECT strftime('%Y', order_date)                                                   AS year,
       ROUND(SUM(CASE WHEN sales_channel = 'Online'   THEN sales_amount ELSE 0 END), 0) AS online_sales,
       ROUND(SUM(CASE WHEN sales_channel = 'In-Store' THEN sales_amount ELSE 0 END), 0) AS in_store_sales,
       ROUND(100.0 * SUM(CASE WHEN sales_channel = 'Online' THEN sales_amount ELSE 0 END)
             / SUM(sales_amount), 1)                                                   AS online_share_pct
FROM order_lines
GROUP BY year
ORDER BY year;

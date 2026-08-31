-- =====================================================================
-- Customer Shopping Analytics — SQL Business Analysis
-- =====================================================================
-- Data loaded via MySQL Workbench's Table Data Import Wizard:
--   Schemas -> customer_behavior -> Tables -> right-click customer
--   -> Table Data Import Wizard -> select cleaned_customer_shopping.csv
--   -> import into this existing table (same approach as the Retail
--   Sales project — no Python-to-MySQL connection needed).
-- =====================================================================

CREATE DATABASE IF NOT EXISTS customer_behavior;
USE customer_behavior;

DROP TABLE IF EXISTS customer;

CREATE TABLE customer (
    customer_id              INT PRIMARY KEY,
    age                      INT,
    gender                   VARCHAR(10),
    item_purchased           VARCHAR(50),
    category                 VARCHAR(50),
    purchase_amount          INT,
    location                 VARCHAR(50),
    size                     VARCHAR(10),
    color                    VARCHAR(30),
    season                   VARCHAR(10),
    review_rating            DECIMAL(3,2),
    subscription_status      VARCHAR(5),
    shipping_type            VARCHAR(20),
    discount_applied         VARCHAR(5),
    previous_purchases       INT,
    payment_method           VARCHAR(20),
    frequency_of_purchases   VARCHAR(20),
    age_group                VARCHAR(20),
    purchase_frequency_days  INT
);

-- After this: use the Table Data Import Wizard (see header note above) to
-- load cleaned_customer_shopping.csv into this table before running anything below.

-- =====================================================================
-- 0. Data validation — run this first, every time, after reloading
-- =====================================================================

-- Expect 3900
SELECT COUNT(*) AS Row_Count FROM customer;

-- Expect both counts equal (no duplicate customer_id)
SELECT COUNT(*) AS Total_Rows, COUNT(DISTINCT customer_id) AS Unique_Customers
FROM customer;

-- Expect 0 — review_rating was imputed in Python, should have no nulls
SELECT COUNT(*) AS Null_Review_Rating
FROM customer
WHERE review_rating IS NULL;

-- Expect 0
SELECT COUNT(*) AS Null_Purchase_Frequency_Days
FROM customer
WHERE purchase_frequency_days IS NULL;

SELECT * FROM customer LIMIT 5;

-- =====================================================================
-- 1. Total revenue by gender
-- =====================================================================

SELECT
    gender,
    SUM(purchase_amount) AS revenue
FROM customer
GROUP BY gender;

-- =====================================================================
-- 2. Customers who used a discount but still spent more than average
-- =====================================================================
-- Strictly "more than" average, not "at or above" — uses > not >=

SELECT
    customer_id,
    purchase_amount
FROM customer
WHERE discount_applied = 'Yes'
  AND purchase_amount > (
      SELECT AVG(purchase_amount)
      FROM customer
  );

-- =====================================================================
-- 3. Top 5 products by average review rating
-- =====================================================================

SELECT
    item_purchased,
    ROUND(AVG(review_rating), 2) AS average_product_rating
FROM customer
GROUP BY item_purchased
ORDER BY average_product_rating DESC
LIMIT 5;

-- =====================================================================
-- 4. Average purchase amount: Standard vs Express shipping
-- =====================================================================

SELECT
    shipping_type,
    ROUND(AVG(purchase_amount), 2) AS average_purchase_amount
FROM customer
WHERE shipping_type IN ('Standard', 'Express')
GROUP BY shipping_type;

-- =====================================================================
-- 5. Do subscribed customers spend more?
-- =====================================================================

SELECT
    subscription_status,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(purchase_amount), 2) AS avg_spend,
    ROUND(SUM(purchase_amount), 2) AS total_revenue
FROM customer
GROUP BY subscription_status
ORDER BY total_revenue DESC, avg_spend DESC;

-- =====================================================================
-- 6. Top 5 products by discount usage rate
-- =====================================================================

SELECT
    item_purchased,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN discount_applied = 'Yes' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS discount_rate
FROM customer
GROUP BY item_purchased
ORDER BY discount_rate DESC
LIMIT 5;

-- =====================================================================
-- 7. Segment customers into New, Returning, and Loyal
-- =====================================================================
-- Assumption: dataset's minimum previous_purchases value is 1 (no customer
-- has 0 previous purchases on record), so "New" = 1 previous purchase,
-- i.e. this is their earliest recorded transaction, not necessarily their
-- literal first-ever purchase.

WITH customer_type AS (
    SELECT
        customer_id,
        previous_purchases,
        CASE
            WHEN previous_purchases = 1 THEN 'New'
            WHEN previous_purchases BETWEEN 2 AND 10 THEN 'Returning'
            ELSE 'Loyal'
        END AS customer_segment
    FROM customer
)
SELECT
    customer_segment,
    COUNT(*) AS number_of_customers
FROM customer_type
GROUP BY customer_segment;

-- =====================================================================
-- 8. Top 3 most purchased products within each category
-- =====================================================================

WITH item_counts AS (
    SELECT
        category,
        item_purchased,
        COUNT(customer_id) AS total_orders,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY COUNT(customer_id) DESC
        ) AS item_rank
    FROM customer
    GROUP BY category, item_purchased
)
SELECT
    item_rank,
    category,
    item_purchased,
    total_orders
FROM item_counts
WHERE item_rank <= 3;

-- =====================================================================
-- 9. Are repeat buyers (> 5 previous purchases) more likely to subscribe?
-- =====================================================================

SELECT
    subscription_status,
    COUNT(customer_id) AS repeat_buyers
FROM customer
WHERE previous_purchases > 5
GROUP BY subscription_status;

-- =====================================================================
-- 10. Revenue contribution by age group
-- =====================================================================
-- age_group boundaries (from Python quartile split):
--   Young Adults: 18-31   Adult: 31-44   Middle-aged: 44-57   Senior: 57-70

SELECT
    age_group,
    SUM(purchase_amount) AS total_revenue
FROM customer
GROUP BY age_group
ORDER BY total_revenue DESC;

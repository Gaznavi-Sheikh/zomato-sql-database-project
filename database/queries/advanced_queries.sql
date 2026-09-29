--------------------------------------------------------------------------------
-- PHASE 6 — ADVANCED QUERIES
--------------------------------------------------------------------------------
-- Sections A-N below build up from multi-table joins through window
-- functions. Thresholds used in HAVING/CASE are calibrated against the
-- actual Phase 5 dataset (not arbitrary round numbers) -- see
-- docs/query-analysis.md and the Phase 6 completion report for the real
-- statistics behind each choice (e.g. restaurant revenue ranges
-- ~11.6K-109K, customer spend ~980-29.6K, order totals ~44-2125).
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- SECTION A: MULTI-TABLE JOINS
--------------------------------------------------------------------------------

-- A1. Customer order history with restaurant name
SELECT c.CUSTOMER_ID, c.FULL_NAME, o.ORDER_ID, r.NAME AS RESTAURANT_NAME,
       o.ORDER_DATE, o.TOTAL_AMOUNT, o.ORDER_STATUS
FROM   CUSTOMER c
JOIN   ORDERS o     ON o.CUSTOMER_ID = c.CUSTOMER_ID
JOIN   RESTAURANT r ON r.RESTAURANT_ID = o.RESTAURANT_ID
ORDER BY c.CUSTOMER_ID, o.ORDER_DATE;

-- A2. Full order detail: customer, restaurant and delivery person together
SELECT o.ORDER_ID, c.FULL_NAME AS CUSTOMER_NAME, r.NAME AS RESTAURANT_NAME,
       d.NAME AS DELIVERY_PERSON_NAME, o.ORDER_STATUS, o.ORDER_DATE, o.TOTAL_AMOUNT
FROM   ORDERS o
JOIN   CUSTOMER c        ON c.CUSTOMER_ID = o.CUSTOMER_ID
JOIN   RESTAURANT r      ON r.RESTAURANT_ID = o.RESTAURANT_ID
LEFT JOIN DELIVERY_PERSON d ON d.DELIVERY_ID = o.DELIVERY_ID  -- LEFT JOIN: DELIVERY_ID is nullable
ORDER BY o.ORDER_DATE DESC
FETCH FIRST 25 ROWS ONLY;

-- A3. Restaurant menu with its category tags (many-to-many via RESTAURANT_CATEGORY)
SELECT r.RESTAURANT_ID, r.NAME AS RESTAURANT_NAME, cat.CATEGORY_NAME
FROM   RESTAURANT r
JOIN   RESTAURANT_CATEGORY rc ON rc.RESTAURANT_ID = r.RESTAURANT_ID
JOIN   CATEGORY cat           ON cat.CATEGORY_ID = rc.CATEGORY_ID
ORDER BY r.RESTAURANT_ID;

-- A4. Complete order detail down to individual menu item names
SELECT o.ORDER_ID, c.FULL_NAME AS CUSTOMER_NAME, r.NAME AS RESTAURANT_NAME,
       mi.ITEM_NAME, oi.QUANTITY, oi.PRICE AS PRICE_AT_ORDER_TIME,
       (oi.QUANTITY * oi.PRICE) AS LINE_TOTAL
FROM   ORDERS o
JOIN   CUSTOMER c    ON c.CUSTOMER_ID = o.CUSTOMER_ID
JOIN   RESTAURANT r  ON r.RESTAURANT_ID = o.RESTAURANT_ID
JOIN   ORDER_ITEM oi ON oi.ORDER_ID = o.ORDER_ID
JOIN   MENU_ITEM mi  ON mi.ITEM_ID = oi.ITEM_ID
WHERE  o.ORDER_ID = 1;

-- A5. Reviewed orders with customer/restaurant info reached THROUGH the order
-- (REVIEW only stores ORDER_ID as of Phase 4 -- CUSTOMER_ID/RESTAURANT_ID are
-- deliberately not duplicated there, so every review report needs this join)
SELECT rv.REVIEW_ID, o.ORDER_ID, c.FULL_NAME AS CUSTOMER_NAME,
       r.NAME AS RESTAURANT_NAME, rv.RATING, rv.COMMENTS, rv.REVIEW_DATE
FROM   REVIEW rv
JOIN   ORDERS o     ON o.ORDER_ID = rv.ORDER_ID
JOIN   CUSTOMER c   ON c.CUSTOMER_ID = o.CUSTOMER_ID
JOIN   RESTAURANT r ON r.RESTAURANT_ID = o.RESTAURANT_ID
ORDER BY rv.REVIEW_DATE DESC
FETCH FIRST 20 ROWS ONLY;

--------------------------------------------------------------------------------
-- SECTION B: AGGREGATION
--------------------------------------------------------------------------------

-- B1. Orders received per restaurant
SELECT r.RESTAURANT_ID, r.NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT
FROM   RESTAURANT r
LEFT JOIN ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY ORDER_COUNT DESC;

-- B2. Revenue generated per restaurant (TOTAL_AMOUNT across all its orders)
SELECT r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY TOTAL_REVENUE DESC;

-- B3. Average order value per restaurant
SELECT r.RESTAURANT_ID, r.NAME, ROUND(AVG(o.TOTAL_AMOUNT), 2) AS AVG_ORDER_VALUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY AVG_ORDER_VALUE DESC;

-- B4. Total amount spent by each customer
SELECT c.CUSTOMER_ID, c.FULL_NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT,
       NVL(SUM(o.TOTAL_AMOUNT), 0) AS TOTAL_SPENT
FROM   CUSTOMER c
LEFT JOIN ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
ORDER BY TOTAL_SPENT DESC;

-- B5. Orders handled per delivery person
SELECT d.DELIVERY_ID, d.NAME, COUNT(o.ORDER_ID) AS ORDERS_HANDLED
FROM   DELIVERY_PERSON d
LEFT JOIN ORDERS o ON o.DELIVERY_ID = d.DELIVERY_ID
GROUP BY d.DELIVERY_ID, d.NAME
ORDER BY ORDERS_HANDLED DESC;

-- B6. Average menu-item price per restaurant (min/max shown for context)
SELECT r.RESTAURANT_ID, r.NAME,
       ROUND(AVG(mi.PRICE), 2) AS AVG_ITEM_PRICE,
       MIN(mi.PRICE) AS CHEAPEST_ITEM,
       MAX(mi.PRICE) AS PRICIEST_ITEM
FROM   RESTAURANT r
JOIN   MENU m       ON m.RESTAURANT_ID = r.RESTAURANT_ID
JOIN   MENU_ITEM mi ON mi.MENU_ID = m.MENU_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY AVG_ITEM_PRICE DESC;

--------------------------------------------------------------------------------
-- SECTION C: GROUP BY + HAVING
--------------------------------------------------------------------------------
-- Thresholds below are calibrated to the actual dataset: restaurant order
-- counts range ~23-187, restaurant revenue ~11.6K-109K, customer spend
-- ~980-29.6K, delivery-person order counts ~15-91, restaurant ratings
-- average 4.1.

-- C1. Restaurants with more than 100 orders (the busier half of the platform)
SELECT r.RESTAURANT_ID, r.NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
HAVING COUNT(o.ORDER_ID) > 100
ORDER BY ORDER_COUNT DESC;

-- C2. Customers whose total spending exceeds 15,000 (well above the ~11.7K average)
SELECT c.CUSTOMER_ID, c.FULL_NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_SPENT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
HAVING SUM(o.TOTAL_AMOUNT) > 15000
ORDER BY TOTAL_SPENT DESC;

-- C3. Delivery persons handling more than 40 orders (top performers)
SELECT d.DELIVERY_ID, d.NAME, COUNT(o.ORDER_ID) AS ORDERS_HANDLED
FROM   DELIVERY_PERSON d
JOIN   ORDERS o ON o.DELIVERY_ID = d.DELIVERY_ID
GROUP BY d.DELIVERY_ID, d.NAME
HAVING COUNT(o.ORDER_ID) > 40
ORDER BY ORDERS_HANDLED DESC;

-- C4. Restaurants with an average rating above 4.3 (above-average performers)
SELECT RESTAURANT_ID, NAME, RATING
FROM   RESTAURANT
WHERE  RATING > 4.3
ORDER BY RATING DESC;

-- C5. Restaurants generating more than 50,000 in total revenue
SELECT r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
HAVING SUM(o.TOTAL_AMOUNT) > 50000
ORDER BY TOTAL_REVENUE DESC;

--------------------------------------------------------------------------------
-- SECTION D: CASE EXPRESSIONS
--------------------------------------------------------------------------------

-- D1. Customer segmentation by total spending
SELECT c.CUSTOMER_ID, c.FULL_NAME, NVL(SUM(o.TOTAL_AMOUNT), 0) AS TOTAL_SPENT,
       CASE
           WHEN SUM(o.TOTAL_AMOUNT) IS NULL      THEN 'NO_ORDERS'
           WHEN SUM(o.TOTAL_AMOUNT) >= 18000      THEN 'HIGH_VALUE'
           WHEN SUM(o.TOTAL_AMOUNT) >= 6000       THEN 'MEDIUM_VALUE'
           ELSE 'LOW_VALUE'
       END AS CUSTOMER_SEGMENT
FROM   CUSTOMER c
LEFT JOIN ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
ORDER BY TOTAL_SPENT DESC;

-- D2. Restaurant performance classification by revenue
SELECT r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE,
       CASE
           WHEN SUM(o.TOTAL_AMOUNT) >= 50000 THEN 'HIGH_PERFORMER'
           WHEN SUM(o.TOTAL_AMOUNT) >= 20000 THEN 'MID_PERFORMER'
           ELSE 'LOW_PERFORMER'
       END AS PERFORMANCE_TIER
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY TOTAL_REVENUE DESC;

-- D3. Classify individual orders into value bands
SELECT ORDER_ID, CUSTOMER_ID, TOTAL_AMOUNT,
       CASE
           WHEN TOTAL_AMOUNT >= 800 THEN 'HIGH_VALUE_ORDER'
           WHEN TOTAL_AMOUNT >= 300 THEN 'MEDIUM_VALUE_ORDER'
           ELSE 'LOW_VALUE_ORDER'
       END AS ORDER_VALUE_BAND
FROM   ORDERS
ORDER BY TOTAL_AMOUNT DESC;

--------------------------------------------------------------------------------
-- SECTION E: SUBQUERIES
--------------------------------------------------------------------------------

-- E1. Scalar subquery: compare each restaurant's revenue to the platform
-- average restaurant revenue (the subquery returns exactly one value, used
-- inline like a constant)
SELECT r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS RESTAURANT_REVENUE,
       (SELECT ROUND(AVG(rev), 2)
        FROM (SELECT SUM(o2.TOTAL_AMOUNT) AS rev
              FROM ORDERS o2 GROUP BY o2.RESTAURANT_ID)) AS AVG_RESTAURANT_REVENUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY RESTAURANT_REVENUE DESC;

-- E2. Non-correlated subquery: customers spending above the average customer
-- spend (the inner query is evaluated once, independent of the outer row)
SELECT c.CUSTOMER_ID, c.FULL_NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_SPENT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
HAVING SUM(o.TOTAL_AMOUNT) > (
    SELECT AVG(cust_total)
    FROM (SELECT SUM(o2.TOTAL_AMOUNT) AS cust_total
          FROM ORDERS o2 GROUP BY o2.CUSTOMER_ID)
)
ORDER BY TOTAL_SPENT DESC;

-- E3. Non-correlated subquery: restaurants earning above the average
-- restaurant revenue
SELECT r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
HAVING SUM(o.TOTAL_AMOUNT) > (
    SELECT AVG(rev) FROM (SELECT SUM(o2.TOTAL_AMOUNT) AS rev
                           FROM ORDERS o2 GROUP BY o2.RESTAURANT_ID)
)
ORDER BY TOTAL_REVENUE DESC;

-- E4. Non-correlated subquery: menu items priced above the overall average
-- item price across the whole platform
SELECT ITEM_ID, ITEM_NAME, PRICE
FROM   MENU_ITEM
WHERE  PRICE > (SELECT AVG(PRICE) FROM MENU_ITEM)
ORDER BY PRICE DESC;

-- E5. CORRELATED subquery: menu items priced above their OWN restaurant's
-- average item price. This must be correlated -- the inner query's average
-- is different for every outer row (it depends on mi.MENU_ID's restaurant),
-- so it cannot be computed once up front like E4's flat platform average.
SELECT mi.ITEM_ID, mi.ITEM_NAME, mi.PRICE, m.RESTAURANT_ID
FROM   MENU_ITEM mi
JOIN   MENU m ON m.MENU_ID = mi.MENU_ID
WHERE  mi.PRICE > (
    SELECT AVG(mi2.PRICE)
    FROM   MENU_ITEM mi2
    JOIN   MENU m2 ON m2.MENU_ID = mi2.MENU_ID
    WHERE  m2.RESTAURANT_ID = m.RESTAURANT_ID   -- correlation: refers to the outer row
)
ORDER BY m.RESTAURANT_ID, mi.PRICE DESC;

-- E6. CORRELATED subquery: customers whose order COUNT exceeds the average
-- order count across all customers. Correlated because each outer customer
-- is compared against a platform-wide figure that must be recomputed
-- relative to the customer being evaluated (expressed here via COUNT(*)
-- inside a HAVING that references the same grouped customer).
SELECT c.CUSTOMER_ID, c.FULL_NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
HAVING COUNT(o.ORDER_ID) > (
    SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM ORDERS GROUP BY CUSTOMER_ID)
)
ORDER BY ORDER_COUNT DESC;

-- E7. CORRELATED subquery: restaurants whose average order value exceeds
-- their OWN typical order value trend -- shown here as orders priced above
-- that same restaurant's average order value (correlated on RESTAURANT_ID)
SELECT o.ORDER_ID, o.RESTAURANT_ID, o.TOTAL_AMOUNT
FROM   ORDERS o
WHERE  o.TOTAL_AMOUNT > (
    SELECT AVG(o2.TOTAL_AMOUNT)
    FROM   ORDERS o2
    WHERE  o2.RESTAURANT_ID = o.RESTAURANT_ID   -- correlation: same restaurant as outer row
)
ORDER BY o.RESTAURANT_ID, o.TOTAL_AMOUNT DESC;

--------------------------------------------------------------------------------
-- SECTION F: EXISTS / NOT EXISTS
--------------------------------------------------------------------------------

-- F1. EXISTS: customers who have placed at least one order
SELECT c.CUSTOMER_ID, c.FULL_NAME
FROM   CUSTOMER c
WHERE  EXISTS (SELECT 1 FROM ORDERS o WHERE o.CUSTOMER_ID = c.CUSTOMER_ID);

-- F2. EXISTS: restaurants that have received at least one review
SELECT r.RESTAURANT_ID, r.NAME
FROM   RESTAURANT r
WHERE  EXISTS (
    SELECT 1 FROM ORDERS o JOIN REVIEW rv ON rv.ORDER_ID = o.ORDER_ID
    WHERE o.RESTAURANT_ID = r.RESTAURANT_ID
);

-- F3. EXISTS: restaurants that have received at least one DELIVERED order
SELECT r.RESTAURANT_ID, r.NAME
FROM   RESTAURANT r
WHERE  EXISTS (
    SELECT 1 FROM ORDERS o
    WHERE o.RESTAURANT_ID = r.RESTAURANT_ID AND o.ORDER_STATUS = 'DELIVERED'
);

-- F4. EXISTS: delivery persons assigned to at least one order
SELECT d.DELIVERY_ID, d.NAME
FROM   DELIVERY_PERSON d
WHERE  EXISTS (SELECT 1 FROM ORDERS o WHERE o.DELIVERY_ID = d.DELIVERY_ID);

-- F5. NOT EXISTS: customers with no orders at all
-- (dataset guarantees a non-empty, meaningful result here: 5 customers)
SELECT c.CUSTOMER_ID, c.FULL_NAME, c.REGISTRATION_DATE
FROM   CUSTOMER c
WHERE  NOT EXISTS (SELECT 1 FROM ORDERS o WHERE o.CUSTOMER_ID = c.CUSTOMER_ID);

-- F6. NOT EXISTS: restaurants that have never received a review
-- NOTE: in the current dataset every restaurant has at least one review, so
-- this legitimately returns 0 rows -- that is itself a real finding (full
-- review coverage), not a broken query. Kept because the technique and the
-- absence-of-rows result are both worth showing.
SELECT r.RESTAURANT_ID, r.NAME
FROM   RESTAURANT r
WHERE  NOT EXISTS (
    SELECT 1 FROM ORDERS o JOIN REVIEW rv ON rv.ORDER_ID = o.ORDER_ID
    WHERE o.RESTAURANT_ID = r.RESTAURANT_ID
);

-- F7. NOT EXISTS: menu items that have never been ordered
-- NOTE: also returns 0 rows in the current dataset (every item has sold at
-- least once) -- a genuine "full catalog utilization" finding.
SELECT mi.ITEM_ID, mi.ITEM_NAME, mi.PRICE
FROM   MENU_ITEM mi
WHERE  NOT EXISTS (SELECT 1 FROM ORDER_ITEM oi WHERE oi.ITEM_ID = mi.ITEM_ID);

-- F8. NOT EXISTS: restaurants with no DELIVERED order (every restaurant has
-- at least one order overall, but not necessarily a successfully delivered one)
SELECT r.RESTAURANT_ID, r.NAME
FROM   RESTAURANT r
WHERE  NOT EXISTS (
    SELECT 1 FROM ORDERS o
    WHERE o.RESTAURANT_ID = r.RESTAURANT_ID AND o.ORDER_STATUS = 'DELIVERED'
);

--------------------------------------------------------------------------------
-- SECTION G: CTEs (WITH clauses)
--------------------------------------------------------------------------------

-- G1. Restaurant revenue ranking: compute revenue per restaurant first,
-- then rank/filter in a second step over the named result set
WITH restaurant_revenue AS (
    SELECT r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE
    FROM   RESTAURANT r
    JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
    GROUP BY r.RESTAURANT_ID, r.NAME
)
SELECT RESTAURANT_ID, NAME, TOTAL_REVENUE,
       RANK() OVER (ORDER BY TOTAL_REVENUE DESC) AS REVENUE_RANK
FROM   restaurant_revenue
ORDER BY REVENUE_RANK;

-- G2. Customer spending vs platform average, computed as two clear steps
WITH customer_spend AS (
    SELECT c.CUSTOMER_ID, c.FULL_NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_SPENT
    FROM   CUSTOMER c
    JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
    GROUP BY c.CUSTOMER_ID, c.FULL_NAME
),
platform_avg AS (
    SELECT AVG(TOTAL_SPENT) AS AVG_SPEND FROM customer_spend
)
SELECT cs.CUSTOMER_ID, cs.FULL_NAME, cs.TOTAL_SPENT, pa.AVG_SPEND,
       ROUND(cs.TOTAL_SPENT - pa.AVG_SPEND, 2) AS DIFF_FROM_AVERAGE
FROM   customer_spend cs
CROSS JOIN platform_avg pa
ORDER BY cs.TOTAL_SPENT DESC;

-- G3. Monthly revenue with month-over-month comparison
WITH monthly_revenue AS (
    SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, SUM(TOTAL_AMOUNT) AS REVENUE
    FROM   ORDERS
    GROUP BY TRUNC(ORDER_DATE, 'MM')
)
SELECT ORDER_MONTH, REVENUE,
       LAG(REVENUE) OVER (ORDER BY ORDER_MONTH) AS PREVIOUS_MONTH_REVENUE,
       REVENUE - LAG(REVENUE) OVER (ORDER BY ORDER_MONTH) AS REVENUE_CHANGE
FROM   monthly_revenue
ORDER BY ORDER_MONTH;

--------------------------------------------------------------------------------
-- SECTION H: CONDITIONAL AGGREGATION
--------------------------------------------------------------------------------

-- H1. Delivered vs cancelled order counts per restaurant, side by side
SELECT r.RESTAURANT_ID, r.NAME,
       COUNT(o.ORDER_ID) AS TOTAL_ORDERS,
       SUM(CASE WHEN o.ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED_ORDERS,
       SUM(CASE WHEN o.ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END) AS CANCELLED_ORDERS
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY TOTAL_ORDERS DESC;

-- H2. Payment coverage: how many orders have a payment row vs. don't
SELECT o.ORDER_STATUS,
       COUNT(o.ORDER_ID) AS TOTAL_ORDERS,
       COUNT(p.PAYMENT_ID) AS ORDERS_WITH_PAYMENT,
       COUNT(o.ORDER_ID) - COUNT(p.PAYMENT_ID) AS ORDERS_WITHOUT_PAYMENT
FROM   ORDERS o
LEFT JOIN PAYMENT p ON p.ORDER_ID = o.ORDER_ID
GROUP BY o.ORDER_STATUS
ORDER BY TOTAL_ORDERS DESC;

-- H3. Overall order-status distribution as percentages
SELECT ORDER_STATUS,
       COUNT(*) AS ORDER_COUNT,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT_OF_ALL_ORDERS
FROM   ORDERS
GROUP BY ORDER_STATUS
ORDER BY ORDER_COUNT DESC;

-- H4. Customers who have both delivered and cancelled orders (mixed history)
SELECT c.CUSTOMER_ID, c.FULL_NAME,
       SUM(CASE WHEN o.ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED_COUNT,
       SUM(CASE WHEN o.ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END) AS CANCELLED_COUNT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
HAVING SUM(CASE WHEN o.ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) > 0
   AND SUM(CASE WHEN o.ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END) > 0
ORDER BY DELIVERED_COUNT DESC;

-- H5. Monthly delivered vs cancelled orders
SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH,
       SUM(CASE WHEN ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED,
       SUM(CASE WHEN ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END) AS CANCELLED
FROM   ORDERS
GROUP BY TRUNC(ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

--------------------------------------------------------------------------------
-- SECTION I: DATE & TIME ANALYSIS
--------------------------------------------------------------------------------

-- I1. Orders per calendar day (busiest days)
SELECT TRUNC(ORDER_DATE) AS ORDER_DAY, COUNT(*) AS ORDER_COUNT
FROM   ORDERS
GROUP BY TRUNC(ORDER_DATE)
ORDER BY ORDER_COUNT DESC
FETCH FIRST 15 ROWS ONLY;

-- I2. Orders per month across the full ~20-month dataset
SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, COUNT(*) AS ORDER_COUNT
FROM   ORDERS
GROUP BY TRUNC(ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

-- I3. Revenue per month
SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, SUM(TOTAL_AMOUNT) AS REVENUE
FROM   ORDERS
GROUP BY TRUNC(ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

-- I4. Monthly average order value
SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, ROUND(AVG(TOTAL_AMOUNT), 2) AS AVG_ORDER_VALUE
FROM   ORDERS
GROUP BY TRUNC(ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

-- I5. The single busiest month by order count
SELECT * FROM (
    SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, COUNT(*) AS ORDER_COUNT
    FROM   ORDERS
    GROUP BY TRUNC(ORDER_DATE, 'MM')
    ORDER BY ORDER_COUNT DESC
) WHERE ROWNUM = 1;

-- I6. A restaurant's own monthly revenue trend
SELECT TRUNC(o.ORDER_DATE, 'MM') AS ORDER_MONTH, SUM(o.TOTAL_AMOUNT) AS REVENUE
FROM   ORDERS o
WHERE  o.RESTAURANT_ID = 1
GROUP BY TRUNC(o.ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

-- I7. A customer's own monthly spending trend
SELECT TRUNC(o.ORDER_DATE, 'MM') AS ORDER_MONTH, SUM(o.TOTAL_AMOUNT) AS MONTHLY_SPEND
FROM   ORDERS o
WHERE  o.CUSTOMER_ID = 1
GROUP BY TRUNC(o.ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

-- I8. Orders by day of week (operational staffing insight)
SELECT TO_CHAR(ORDER_DATE, 'DY') AS DAY_OF_WEEK, COUNT(*) AS ORDER_COUNT
FROM   ORDERS
GROUP BY TO_CHAR(ORDER_DATE, 'DY')
ORDER BY ORDER_COUNT DESC;

-- I9. Recent orders (last 30 days relative to the dataset's latest order)
SELECT ORDER_ID, CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT
FROM   ORDERS
WHERE  ORDER_DATE >= (SELECT MAX(ORDER_DATE) FROM ORDERS) - 30
ORDER BY ORDER_DATE DESC;

-- I10. Oldest and newest orders in the dataset
SELECT MIN(ORDER_DATE) AS OLDEST_ORDER, MAX(ORDER_DATE) AS NEWEST_ORDER
FROM   ORDERS;

-- I11. (also see Section H5) Monthly delivered vs cancelled -- repeated here
-- grouped instead by EXTRACT(YEAR/MONTH) to demonstrate the alternative to TRUNC
SELECT EXTRACT(YEAR FROM ORDER_DATE) AS ORDER_YEAR,
       EXTRACT(MONTH FROM ORDER_DATE) AS ORDER_MONTH_NUM,
       SUM(CASE WHEN ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED,
       SUM(CASE WHEN ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END) AS CANCELLED
FROM   ORDERS
GROUP BY EXTRACT(YEAR FROM ORDER_DATE), EXTRACT(MONTH FROM ORDER_DATE)
ORDER BY ORDER_YEAR, ORDER_MONTH_NUM;

--------------------------------------------------------------------------------
-- SECTION J: WINDOW FUNCTIONS -- RANKING
--------------------------------------------------------------------------------

-- J1. Restaurants ranked by revenue
SELECT RESTAURANT_ID, NAME, TOTAL_REVENUE,
       RANK() OVER (ORDER BY TOTAL_REVENUE DESC) AS REVENUE_RANK
FROM (
    SELECT r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE
    FROM   RESTAURANT r JOIN ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
    GROUP BY r.RESTAURANT_ID, r.NAME
);

-- J2. Customers ranked by spending
SELECT CUSTOMER_ID, FULL_NAME, TOTAL_SPENT,
       RANK() OVER (ORDER BY TOTAL_SPENT DESC) AS SPEND_RANK
FROM (
    SELECT c.CUSTOMER_ID, c.FULL_NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_SPENT
    FROM   CUSTOMER c JOIN ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
    GROUP BY c.CUSTOMER_ID, c.FULL_NAME
);

-- J3. Delivery persons ranked by completed (DELIVERED) deliveries
SELECT DELIVERY_ID, NAME, DELIVERED_COUNT,
       RANK() OVER (ORDER BY DELIVERED_COUNT DESC) AS DELIVERY_RANK
FROM (
    SELECT d.DELIVERY_ID, d.NAME,
           SUM(CASE WHEN o.ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED_COUNT
    FROM   DELIVERY_PERSON d
    LEFT JOIN ORDERS o ON o.DELIVERY_ID = d.DELIVERY_ID
    GROUP BY d.DELIVERY_ID, d.NAME
);

-- J4. Menu items ranked by total quantity sold
SELECT ITEM_ID, ITEM_NAME, UNITS_SOLD,
       RANK() OVER (ORDER BY UNITS_SOLD DESC) AS SALES_RANK
FROM (
    SELECT mi.ITEM_ID, mi.ITEM_NAME, SUM(oi.QUANTITY) AS UNITS_SOLD
    FROM   MENU_ITEM mi JOIN ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
    GROUP BY mi.ITEM_ID, mi.ITEM_NAME
);

-- J5. Restaurants ranked WITHIN each city (PARTITION BY city)
SELECT RESTAURANT_ID, NAME, CITY, TOTAL_REVENUE,
       RANK() OVER (PARTITION BY CITY ORDER BY TOTAL_REVENUE DESC) AS RANK_IN_CITY
FROM (
    SELECT r.RESTAURANT_ID, r.NAME, r.CITY, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE
    FROM   RESTAURANT r JOIN ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
    GROUP BY r.RESTAURANT_ID, r.NAME, r.CITY
)
ORDER BY CITY, RANK_IN_CITY;

-- J6. Menu items ranked WITHIN each restaurant by revenue
SELECT RESTAURANT_ID, ITEM_NAME, ITEM_REVENUE,
       RANK() OVER (PARTITION BY RESTAURANT_ID ORDER BY ITEM_REVENUE DESC) AS RANK_IN_RESTAURANT
FROM (
    SELECT m.RESTAURANT_ID, mi.ITEM_NAME, SUM(oi.QUANTITY * oi.PRICE) AS ITEM_REVENUE
    FROM   MENU_ITEM mi
    JOIN   MENU m       ON m.MENU_ID = mi.MENU_ID
    JOIN   ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
    GROUP BY m.RESTAURANT_ID, mi.ITEM_NAME
)
ORDER BY RESTAURANT_ID, RANK_IN_RESTAURANT;

-- J7. ROW_NUMBER vs RANK vs DENSE_RANK on a column where TIES genuinely
-- occur: RESTAURANT.RATING is stored to one decimal place, so several
-- restaurants legitimately share the exact same rating.
--
-- ROW_NUMBER:  always assigns 1,2,3,4... with no ties -- ties are broken
--              arbitrarily (here, by RESTAURANT_ID as a deterministic
--              tiebreaker), so two restaurants with the same rating still
--              get two different numbers.
-- RANK:        ties get the SAME rank, but the next rank SKIPS ahead by
--              the number of tied rows (e.g. two restaurants tied at rank 2
--              means the next distinct rating is rank 4, not 3).
-- DENSE_RANK:  ties get the SAME rank, and the next distinct rating gets
--              the NEXT CONSECUTIVE rank with no gap (rank 3, not 4).
SELECT RESTAURANT_ID, NAME, RATING,
       ROW_NUMBER() OVER (ORDER BY RATING DESC, RESTAURANT_ID) AS ROW_NUM,
       RANK()       OVER (ORDER BY RATING DESC) AS RATING_RANK,
       DENSE_RANK() OVER (ORDER BY RATING DESC) AS RATING_DENSE_RANK
FROM   RESTAURANT
ORDER BY RATING DESC, RESTAURANT_ID;

--------------------------------------------------------------------------------
-- SECTION K: TOP-N PER GROUP (partitioned ranking, not a global FETCH FIRST)
--------------------------------------------------------------------------------

-- K1. Top 5 menu items per restaurant, by quantity sold
SELECT * FROM (
    SELECT m.RESTAURANT_ID, mi.ITEM_NAME, SUM(oi.QUANTITY) AS UNITS_SOLD,
           ROW_NUMBER() OVER (PARTITION BY m.RESTAURANT_ID ORDER BY SUM(oi.QUANTITY) DESC) AS RN
    FROM   MENU_ITEM mi
    JOIN   MENU m        ON m.MENU_ID = mi.MENU_ID
    JOIN   ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
    GROUP BY m.RESTAURANT_ID, mi.ITEM_NAME
)
WHERE RN <= 5
ORDER BY RESTAURANT_ID, RN;

-- K2. Top 3 customers per city (by total spending), based on their HOME address city
SELECT * FROM (
    SELECT a.CITY, c.CUSTOMER_ID, c.FULL_NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_SPENT,
           ROW_NUMBER() OVER (PARTITION BY a.CITY ORDER BY SUM(o.TOTAL_AMOUNT) DESC) AS RN
    FROM   CUSTOMER c
    JOIN   ORDERS o  ON o.CUSTOMER_ID = c.CUSTOMER_ID
    JOIN   ADDRESS a ON a.ADDRESS_ID = o.ADDRESS_ID
    GROUP BY a.CITY, c.CUSTOMER_ID, c.FULL_NAME
)
WHERE RN <= 3
ORDER BY CITY, RN;

-- K3. Top restaurant(s) per city by revenue
SELECT * FROM (
    SELECT r.CITY, r.RESTAURANT_ID, r.NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE,
           ROW_NUMBER() OVER (PARTITION BY r.CITY ORDER BY SUM(o.TOTAL_AMOUNT) DESC) AS RN
    FROM   RESTAURANT r
    JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
    GROUP BY r.CITY, r.RESTAURANT_ID, r.NAME
)
WHERE RN = 1
ORDER BY CITY;

-- K4. Top 3 menu items BY REVENUE for each restaurant
SELECT * FROM (
    SELECT m.RESTAURANT_ID, mi.ITEM_NAME, SUM(oi.QUANTITY * oi.PRICE) AS ITEM_REVENUE,
           ROW_NUMBER() OVER (PARTITION BY m.RESTAURANT_ID ORDER BY SUM(oi.QUANTITY * oi.PRICE) DESC) AS RN
    FROM   MENU_ITEM mi
    JOIN   MENU m        ON m.MENU_ID = mi.MENU_ID
    JOIN   ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
    GROUP BY m.RESTAURANT_ID, mi.ITEM_NAME
)
WHERE RN <= 3
ORDER BY RESTAURANT_ID, RN;

--------------------------------------------------------------------------------
-- SECTION L: LAG / LEAD (customer order history analysis)
--------------------------------------------------------------------------------

-- L1 & L4. Previous order date AND previous order amount for each customer
SELECT CUSTOMER_ID, ORDER_ID, ORDER_DATE, TOTAL_AMOUNT,
       LAG(ORDER_DATE)    OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS PREVIOUS_ORDER_DATE,
       LAG(TOTAL_AMOUNT)  OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS PREVIOUS_ORDER_AMOUNT
FROM   ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;

-- L2. Next order date for each customer (the mirror image of LAG)
SELECT CUSTOMER_ID, ORDER_ID, ORDER_DATE,
       LEAD(ORDER_DATE) OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS NEXT_ORDER_DATE
FROM   ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;

-- L3. Days between consecutive orders for each customer
SELECT CUSTOMER_ID, ORDER_ID, ORDER_DATE,
       ORDER_DATE - LAG(ORDER_DATE) OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS DAYS_SINCE_LAST_ORDER
FROM   ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;

-- L5. Change in order amount compared with the previous order
SELECT CUSTOMER_ID, ORDER_ID, ORDER_DATE, TOTAL_AMOUNT,
       TOTAL_AMOUNT - LAG(TOTAL_AMOUNT) OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS AMOUNT_CHANGE
FROM   ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;

-- L6. Customers whose most recent order was larger than their previous one
SELECT * FROM (
    SELECT CUSTOMER_ID, ORDER_ID, ORDER_DATE, TOTAL_AMOUNT,
           LAG(TOTAL_AMOUNT) OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE) AS PREVIOUS_AMOUNT,
           ROW_NUMBER() OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE DESC) AS RECENCY_RANK
    FROM   ORDERS
)
WHERE RECENCY_RANK = 1
  AND PREVIOUS_AMOUNT IS NOT NULL
  AND TOTAL_AMOUNT > PREVIOUS_AMOUNT
ORDER BY (TOTAL_AMOUNT - PREVIOUS_AMOUNT) DESC;

--------------------------------------------------------------------------------
-- SECTION M: RUNNING TOTALS
--------------------------------------------------------------------------------
-- Window aggregation is preferable to a self-join here because a running
-- total via self-join requires joining the table to itself on an
-- inequality (o2.ORDER_DATE <= o1.ORDER_DATE), which multiplies row counts
-- (an O(n^2) comparison) and gets slower and harder to read as the table
-- grows. A window function computes the same result in a single pass over
-- data already sorted for the frame, and reads as a direct statement of
-- intent ("sum everything up to this row") rather than an implicit join
-- condition standing in for that idea.

-- M1. Cumulative platform-wide revenue over time
SELECT ORDER_DATE, TOTAL_AMOUNT,
       SUM(TOTAL_AMOUNT) OVER (ORDER BY ORDER_DATE
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CUMULATIVE_REVENUE
FROM   ORDERS
ORDER BY ORDER_DATE;

-- M2. Cumulative order count over time
SELECT ORDER_DATE,
       COUNT(*) OVER (ORDER BY ORDER_DATE
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CUMULATIVE_ORDER_COUNT
FROM   ORDERS
ORDER BY ORDER_DATE;

-- M3. Cumulative spending per customer over time (their running lifetime value)
SELECT CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT,
       SUM(TOTAL_AMOUNT) OVER (PARTITION BY CUSTOMER_ID ORDER BY ORDER_DATE
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CUMULATIVE_CUSTOMER_SPEND
FROM   ORDERS
ORDER BY CUSTOMER_ID, ORDER_DATE;

-- M4. Restaurant cumulative revenue by month
SELECT RESTAURANT_ID, ORDER_MONTH, MONTHLY_REVENUE,
       SUM(MONTHLY_REVENUE) OVER (PARTITION BY RESTAURANT_ID ORDER BY ORDER_MONTH
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CUMULATIVE_REVENUE
FROM (
    SELECT RESTAURANT_ID, TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, SUM(TOTAL_AMOUNT) AS MONTHLY_REVENUE
    FROM   ORDERS
    GROUP BY RESTAURANT_ID, TRUNC(ORDER_DATE, 'MM')
)
ORDER BY RESTAURANT_ID, ORDER_MONTH;

--------------------------------------------------------------------------------
-- SECTION N: ABOVE-AVERAGE ANALYSIS
--------------------------------------------------------------------------------

-- N1. Customers spending above the platform average (CTE version)
WITH customer_spend AS (
    SELECT CUSTOMER_ID, SUM(TOTAL_AMOUNT) AS TOTAL_SPENT FROM ORDERS GROUP BY CUSTOMER_ID
)
SELECT c.CUSTOMER_ID, c.FULL_NAME, cs.TOTAL_SPENT
FROM   customer_spend cs
JOIN   CUSTOMER c ON c.CUSTOMER_ID = cs.CUSTOMER_ID
WHERE  cs.TOTAL_SPENT > (SELECT AVG(TOTAL_SPENT) FROM customer_spend)
ORDER BY cs.TOTAL_SPENT DESC;

-- N2. Restaurants earning above the platform average
WITH restaurant_revenue AS (
    SELECT RESTAURANT_ID, SUM(TOTAL_AMOUNT) AS TOTAL_REVENUE FROM ORDERS GROUP BY RESTAURANT_ID
)
SELECT r.RESTAURANT_ID, r.NAME, rr.TOTAL_REVENUE
FROM   restaurant_revenue rr
JOIN   RESTAURANT r ON r.RESTAURANT_ID = rr.RESTAURANT_ID
WHERE  rr.TOTAL_REVENUE > (SELECT AVG(TOTAL_REVENUE) FROM restaurant_revenue)
ORDER BY rr.TOTAL_REVENUE DESC;

-- N3. Orders above the platform average order value
SELECT ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, TOTAL_AMOUNT
FROM   ORDERS
WHERE  TOTAL_AMOUNT > (SELECT AVG(TOTAL_AMOUNT) FROM ORDERS)
ORDER BY TOTAL_AMOUNT DESC;

-- N4. Menu items priced above their own restaurant's average price
-- (identical technique to E5 -- correlated subquery -- repeated here under
-- its "above-average" framing per the phase brief)
SELECT mi.ITEM_ID, mi.ITEM_NAME, mi.PRICE, m.RESTAURANT_ID
FROM   MENU_ITEM mi
JOIN   MENU m ON m.MENU_ID = mi.MENU_ID
WHERE  mi.PRICE > (
    SELECT AVG(mi2.PRICE) FROM MENU_ITEM mi2 JOIN MENU m2 ON m2.MENU_ID = mi2.MENU_ID
    WHERE m2.RESTAURANT_ID = m.RESTAURANT_ID
)
ORDER BY m.RESTAURANT_ID, mi.PRICE DESC;

-- N5. Restaurants whose rating is above the average restaurant rating
SELECT RESTAURANT_ID, NAME, RATING
FROM   RESTAURANT
WHERE  RATING > (SELECT AVG(RATING) FROM RESTAURANT)
ORDER BY RATING DESC;

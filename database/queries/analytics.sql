--------------------------------------------------------------------------------
-- PHASE 6 — BUSINESS ANALYTICS
--------------------------------------------------------------------------------
-- Dedicated business-question queries, organized by domain area, plus a
-- focused Historical Price Analysis section proving out why
-- ORDER_ITEM.PRICE exists as a separate column from MENU_ITEM.PRICE
-- (Phase 4, Deep Dive 1). Some NOT-EXISTS-style findings below legitimately
-- return zero rows against the current dataset (every restaurant has a
-- review, every menu item has sold, every delivery person has an order) --
-- that is a genuine finding, not a broken query, and is called out inline
-- rather than silently glossed over.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- RESTAURANT ANALYTICS
--------------------------------------------------------------------------------

-- Top restaurants by revenue
SELECT r.RESTAURANT_ID, r.NAME, r.CITY, SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME, r.CITY
ORDER BY TOTAL_REVENUE DESC
FETCH FIRST 10 ROWS ONLY;

-- Top restaurants by order count
SELECT r.RESTAURANT_ID, r.NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY ORDER_COUNT DESC
FETCH FIRST 10 ROWS ONLY;

-- Average order value by restaurant
SELECT r.RESTAURANT_ID, r.NAME, ROUND(AVG(o.TOTAL_AMOUNT), 2) AS AVG_ORDER_VALUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY AVG_ORDER_VALUE DESC;

-- Restaurants with high cancellation rates (>15% of their own orders cancelled)
SELECT r.RESTAURANT_ID, r.NAME,
       COUNT(o.ORDER_ID) AS TOTAL_ORDERS,
       SUM(CASE WHEN o.ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END) AS CANCELLED_ORDERS,
       ROUND(100 * SUM(CASE WHEN o.ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END)
                 / COUNT(o.ORDER_ID), 2) AS CANCELLATION_RATE_PCT
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
HAVING 100 * SUM(CASE WHEN o.ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END)
           / COUNT(o.ORDER_ID) > 15
ORDER BY CANCELLATION_RATE_PCT DESC;

-- Restaurants with no reviews
-- NOTE: returns 0 rows in the current dataset -- every restaurant has at
-- least one review. A genuine "full review coverage" finding, kept for the
-- technique.
SELECT r.RESTAURANT_ID, r.NAME
FROM   RESTAURANT r
WHERE  NOT EXISTS (
    SELECT 1 FROM ORDERS o JOIN REVIEW rv ON rv.ORDER_ID = o.ORDER_ID
    WHERE o.RESTAURANT_ID = r.RESTAURANT_ID
);

-- Restaurant performance by city
SELECT r.CITY,
       COUNT(DISTINCT r.RESTAURANT_ID) AS RESTAURANT_COUNT,
       COUNT(o.ORDER_ID) AS TOTAL_ORDERS,
       SUM(o.TOTAL_AMOUNT) AS TOTAL_REVENUE,
       ROUND(AVG(o.TOTAL_AMOUNT), 2) AS AVG_ORDER_VALUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.CITY
ORDER BY TOTAL_REVENUE DESC;

--------------------------------------------------------------------------------
-- CUSTOMER ANALYTICS
--------------------------------------------------------------------------------

-- Top customers by spending
SELECT c.CUSTOMER_ID, c.FULL_NAME, SUM(o.TOTAL_AMOUNT) AS TOTAL_SPENT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
ORDER BY TOTAL_SPENT DESC
FETCH FIRST 10 ROWS ONLY;

-- Top customers by order count
SELECT c.CUSTOMER_ID, c.FULL_NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
ORDER BY ORDER_COUNT DESC
FETCH FIRST 10 ROWS ONLY;

-- Customers with no orders (dataset guarantees a real, non-empty result: 5 customers)
SELECT CUSTOMER_ID, FULL_NAME, REGISTRATION_DATE
FROM   CUSTOMER c
WHERE  NOT EXISTS (SELECT 1 FROM ORDERS o WHERE o.CUSTOMER_ID = c.CUSTOMER_ID)
ORDER BY CUSTOMER_ID;

-- Repeat customers (more than one order)
SELECT c.CUSTOMER_ID, c.FULL_NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
HAVING COUNT(o.ORDER_ID) > 1
ORDER BY ORDER_COUNT DESC;

-- Average order value per customer
SELECT c.CUSTOMER_ID, c.FULL_NAME, ROUND(AVG(o.TOTAL_AMOUNT), 2) AS AVG_ORDER_VALUE
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
ORDER BY AVG_ORDER_VALUE DESC;

-- Customer monthly spending
SELECT c.CUSTOMER_ID, c.FULL_NAME, TRUNC(o.ORDER_DATE, 'MM') AS ORDER_MONTH,
       SUM(o.TOTAL_AMOUNT) AS MONTHLY_SPEND
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME, TRUNC(o.ORDER_DATE, 'MM')
ORDER BY c.CUSTOMER_ID, ORDER_MONTH;

--------------------------------------------------------------------------------
-- MENU ANALYTICS
--------------------------------------------------------------------------------

-- Best-selling menu items (by units sold)
SELECT mi.ITEM_ID, mi.ITEM_NAME, SUM(oi.QUANTITY) AS UNITS_SOLD
FROM   MENU_ITEM mi
JOIN   ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
GROUP BY mi.ITEM_ID, mi.ITEM_NAME
ORDER BY UNITS_SOLD DESC
FETCH FIRST 10 ROWS ONLY;

-- Highest-revenue menu items
SELECT mi.ITEM_ID, mi.ITEM_NAME, SUM(oi.QUANTITY * oi.PRICE) AS ITEM_REVENUE
FROM   MENU_ITEM mi
JOIN   ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
GROUP BY mi.ITEM_ID, mi.ITEM_NAME
ORDER BY ITEM_REVENUE DESC
FETCH FIRST 10 ROWS ONLY;

-- Most expensive menu items on the platform
SELECT ITEM_ID, ITEM_NAME, PRICE
FROM   MENU_ITEM
ORDER BY PRICE DESC
FETCH FIRST 10 ROWS ONLY;

-- Menu items never ordered
-- NOTE: returns 0 rows in the current dataset -- full catalog utilization.
SELECT mi.ITEM_ID, mi.ITEM_NAME, mi.PRICE
FROM   MENU_ITEM mi
WHERE  NOT EXISTS (SELECT 1 FROM ORDER_ITEM oi WHERE oi.ITEM_ID = mi.ITEM_ID);

-- Top 5 items per restaurant (by revenue) -- see advanced_queries.sql K4 for
-- the full partitioned-ranking version; repeated here for the analytics index
SELECT * FROM (
    SELECT m.RESTAURANT_ID, mi.ITEM_NAME, SUM(oi.QUANTITY * oi.PRICE) AS ITEM_REVENUE,
           ROW_NUMBER() OVER (PARTITION BY m.RESTAURANT_ID ORDER BY SUM(oi.QUANTITY * oi.PRICE) DESC) AS RN
    FROM   MENU_ITEM mi
    JOIN   MENU m        ON m.MENU_ID = mi.MENU_ID
    JOIN   ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
    GROUP BY m.RESTAURANT_ID, mi.ITEM_NAME
)
WHERE RN <= 5
ORDER BY RESTAURANT_ID, RN;

--------------------------------------------------------------------------------
-- DELIVERY ANALYTICS
--------------------------------------------------------------------------------

-- Delivery persons by total order count
SELECT d.DELIVERY_ID, d.NAME, COUNT(o.ORDER_ID) AS ORDER_COUNT
FROM   DELIVERY_PERSON d
LEFT JOIN ORDERS o ON o.DELIVERY_ID = d.DELIVERY_ID
GROUP BY d.DELIVERY_ID, d.NAME
ORDER BY ORDER_COUNT DESC;

-- Delivery persons by successfully DELIVERED orders specifically
SELECT d.DELIVERY_ID, d.NAME,
       SUM(CASE WHEN o.ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED_COUNT
FROM   DELIVERY_PERSON d
LEFT JOIN ORDERS o ON o.DELIVERY_ID = d.DELIVERY_ID
GROUP BY d.DELIVERY_ID, d.NAME
ORDER BY DELIVERED_COUNT DESC;

-- Delivery persons with no assigned orders
-- NOTE: returns 0 rows in the current dataset -- every delivery person has
-- at least one assigned order.
SELECT d.DELIVERY_ID, d.NAME
FROM   DELIVERY_PERSON d
WHERE  NOT EXISTS (SELECT 1 FROM ORDERS o WHERE o.DELIVERY_ID = d.DELIVERY_ID);

-- Delivery workload distribution (min/avg/max orders per delivery person)
SELECT MIN(ORDER_COUNT) AS MIN_WORKLOAD,
       ROUND(AVG(ORDER_COUNT), 2) AS AVG_WORKLOAD,
       MAX(ORDER_COUNT) AS MAX_WORKLOAD
FROM (
    SELECT d.DELIVERY_ID, COUNT(o.ORDER_ID) AS ORDER_COUNT
    FROM   DELIVERY_PERSON d
    LEFT JOIN ORDERS o ON o.DELIVERY_ID = d.DELIVERY_ID
    GROUP BY d.DELIVERY_ID
);

--------------------------------------------------------------------------------
-- ORDER ANALYTICS
--------------------------------------------------------------------------------

-- Total orders on the platform
SELECT COUNT(*) AS TOTAL_ORDERS FROM ORDERS;

-- Delivered / cancelled / in-progress distribution
SELECT ORDER_STATUS, COUNT(*) AS ORDER_COUNT,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT_OF_TOTAL
FROM   ORDERS
GROUP BY ORDER_STATUS
ORDER BY ORDER_COUNT DESC;

-- Average order value across the whole platform
SELECT ROUND(AVG(TOTAL_AMOUNT), 2) AS AVG_ORDER_VALUE FROM ORDERS;

-- Highest-value orders
SELECT ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, ORDER_DATE, TOTAL_AMOUNT
FROM   ORDERS
ORDER BY TOTAL_AMOUNT DESC
FETCH FIRST 10 ROWS ONLY;

-- Monthly order-count trend
SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, COUNT(*) AS ORDER_COUNT
FROM   ORDERS
GROUP BY TRUNC(ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

-- Monthly revenue trend
SELECT TRUNC(ORDER_DATE, 'MM') AS ORDER_MONTH, SUM(TOTAL_AMOUNT) AS REVENUE
FROM   ORDERS
GROUP BY TRUNC(ORDER_DATE, 'MM')
ORDER BY ORDER_MONTH;

--------------------------------------------------------------------------------
-- PAYMENT ANALYTICS
--------------------------------------------------------------------------------

-- Payment coverage: how many orders have a payment vs. don't, by status
SELECT o.ORDER_STATUS,
       COUNT(o.ORDER_ID) AS TOTAL_ORDERS,
       COUNT(p.PAYMENT_ID) AS WITH_PAYMENT,
       COUNT(o.ORDER_ID) - COUNT(p.PAYMENT_ID) AS WITHOUT_PAYMENT
FROM   ORDERS o
LEFT JOIN PAYMENT p ON p.ORDER_ID = o.ORDER_ID
GROUP BY o.ORDER_STATUS
ORDER BY TOTAL_ORDERS DESC;

-- Payment totals by payment mode
SELECT PAYMENT_MODE, COUNT(*) AS PAYMENT_COUNT, SUM(AMOUNT) AS TOTAL_AMOUNT
FROM   PAYMENT
GROUP BY PAYMENT_MODE
ORDER BY TOTAL_AMOUNT DESC;

-- Payment status breakdown
SELECT PAYMENT_STATUS, COUNT(*) AS PAYMENT_COUNT, SUM(AMOUNT) AS TOTAL_AMOUNT
FROM   PAYMENT
GROUP BY PAYMENT_STATUS
ORDER BY PAYMENT_COUNT DESC;

-- Unpaid CANCELLED orders (cancelled before a payment was ever captured --
-- see docs/seed-data.md sec 7: this is intentional data, not a bug)
SELECT o.ORDER_ID, o.CUSTOMER_ID, o.RESTAURANT_ID, o.TOTAL_AMOUNT, o.ORDER_DATE
FROM   ORDERS o
WHERE  o.ORDER_STATUS = 'CANCELLED'
  AND  NOT EXISTS (SELECT 1 FROM PAYMENT p WHERE p.ORDER_ID = o.ORDER_ID)
ORDER BY o.ORDER_DATE DESC;

--------------------------------------------------------------------------------
-- REVIEW ANALYTICS
--------------------------------------------------------------------------------

-- Average rating by restaurant (from actual REVIEW rows, reached via ORDERS --
-- distinct from the possibly-independent cached RESTAURANT.RATING column;
-- see docs/normalization.md Deep Dive 4 for why both can legitimately differ)
SELECT r.RESTAURANT_ID, r.NAME, r.RATING AS STORED_RATING,
       ROUND(AVG(rv.RATING), 2) AS AVG_REVIEW_RATING,
       COUNT(rv.REVIEW_ID) AS REVIEW_COUNT
FROM   RESTAURANT r
JOIN   ORDERS o  ON o.RESTAURANT_ID = r.RESTAURANT_ID
JOIN   REVIEW rv ON rv.ORDER_ID = o.ORDER_ID
GROUP BY r.RESTAURANT_ID, r.NAME, r.RATING
ORDER BY AVG_REVIEW_RATING DESC;

-- Review count by restaurant
SELECT r.RESTAURANT_ID, r.NAME, COUNT(rv.REVIEW_ID) AS REVIEW_COUNT
FROM   RESTAURANT r
JOIN   ORDERS o  ON o.RESTAURANT_ID = r.RESTAURANT_ID
JOIN   REVIEW rv ON rv.ORDER_ID = o.ORDER_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY REVIEW_COUNT DESC;

-- Overall rating distribution
SELECT RATING, COUNT(*) AS REVIEW_COUNT
FROM   REVIEW
GROUP BY RATING
ORDER BY RATING DESC;

-- Restaurants with no reviews (repeated from the RESTAURANT section for the
-- Reviews index -- returns 0 rows currently, see note above)
SELECT r.RESTAURANT_ID, r.NAME
FROM   RESTAURANT r
WHERE  NOT EXISTS (
    SELECT 1 FROM ORDERS o JOIN REVIEW rv ON rv.ORDER_ID = o.ORDER_ID
    WHERE o.RESTAURANT_ID = r.RESTAURANT_ID
);

-- Review trend over time (monthly review volume and average rating)
SELECT TRUNC(REVIEW_DATE, 'MM') AS REVIEW_MONTH,
       COUNT(*) AS REVIEW_COUNT,
       ROUND(AVG(RATING), 2) AS AVG_RATING
FROM   REVIEW
GROUP BY TRUNC(REVIEW_DATE, 'MM')
ORDER BY REVIEW_MONTH;

--------------------------------------------------------------------------------
-- HISTORICAL PRICE ANALYSIS
--------------------------------------------------------------------------------
-- Demonstrates precisely why ORDER_ITEM.PRICE exists as its own column
-- (Phase 4, Deep Dive 1) instead of being derived by joining to
-- MENU_ITEM.PRICE. ORDER_ITEM.PRICE is NEVER replaced with MENU_ITEM.PRICE
-- in any query in this project -- doing so would silently rewrite
-- historical order totals every time a restaurant changes a price.

-- 1-3. Current menu price vs. historical order price vs. their difference
SELECT oi.ORDER_ID, oi.ITEM_ID, mi.ITEM_NAME,
       oi.PRICE      AS HISTORICAL_ORDER_PRICE,
       mi.PRICE      AS CURRENT_MENU_PRICE,
       mi.PRICE - oi.PRICE AS PRICE_DIFFERENCE
FROM   ORDER_ITEM oi
JOIN   MENU_ITEM mi ON mi.ITEM_ID = oi.ITEM_ID
WHERE  oi.PRICE <> mi.PRICE
ORDER BY PRICE_DIFFERENCE DESC
FETCH FIRST 20 ROWS ONLY;

-- 4. Percentage difference between historical and current price
SELECT oi.ORDER_ID, oi.ITEM_ID, mi.ITEM_NAME,
       oi.PRICE AS HISTORICAL_PRICE, mi.PRICE AS CURRENT_PRICE,
       ROUND(100 * (mi.PRICE - oi.PRICE) / oi.PRICE, 2) AS PCT_INCREASE_SINCE_ORDER
FROM   ORDER_ITEM oi
JOIN   MENU_ITEM mi ON mi.ITEM_ID = oi.ITEM_ID
WHERE  oi.PRICE <> mi.PRICE
ORDER BY PCT_INCREASE_SINCE_ORDER DESC
FETCH FIRST 20 ROWS ONLY;

-- 5. How many / what share of all order items show a historical price
-- difference at all (proves the phenomenon is real and non-trivial, not a
-- rare fluke)
SELECT COUNT(*) AS TOTAL_ORDER_ITEMS,
       SUM(CASE WHEN oi.PRICE <> mi.PRICE THEN 1 ELSE 0 END) AS DIVERGENT_ITEMS,
       ROUND(100 * SUM(CASE WHEN oi.PRICE <> mi.PRICE THEN 1 ELSE 0 END) / COUNT(*), 2) AS PCT_DIVERGENT
FROM   ORDER_ITEM oi
JOIN   MENU_ITEM mi ON mi.ITEM_ID = oi.ITEM_ID;

-- 6. Average historical discount by restaurant (only over items that
-- actually diverge, i.e. WHERE the historical price differs from today's)
SELECT m.RESTAURANT_ID,
       ROUND(AVG(mi.PRICE - oi.PRICE), 2) AS AVG_PRICE_INCREASE_SINCE_ORDER,
       COUNT(*) AS DIVERGENT_ORDER_ITEMS
FROM   ORDER_ITEM oi
JOIN   MENU_ITEM mi ON mi.ITEM_ID = oi.ITEM_ID
JOIN   MENU m        ON m.MENU_ID = mi.MENU_ID
WHERE  oi.PRICE <> mi.PRICE
GROUP BY m.RESTAURANT_ID
ORDER BY AVG_PRICE_INCREASE_SINCE_ORDER DESC;

-- 7. Oldest vs. current price comparison for a single item across its order history
SELECT oi.ORDER_ID, o.ORDER_DATE, oi.PRICE AS PRICE_CHARGED,
       mi.PRICE AS CURRENT_PRICE
FROM   ORDER_ITEM oi
JOIN   ORDERS o     ON o.ORDER_ID = oi.ORDER_ID
JOIN   MENU_ITEM mi ON mi.ITEM_ID = oi.ITEM_ID
WHERE  oi.ITEM_ID = (
    -- pick the item with the most order history, for a meaningful example
    SELECT ITEM_ID FROM (
        SELECT ITEM_ID, COUNT(*) AS CNT FROM ORDER_ITEM GROUP BY ITEM_ID ORDER BY CNT DESC
    ) WHERE ROWNUM = 1
)
ORDER BY o.ORDER_DATE;

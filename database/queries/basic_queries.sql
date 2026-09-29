--------------------------------------------------------------------------------
-- PHASE 6 — BASIC QUERIES
--------------------------------------------------------------------------------
-- Foundational filtering, sorting and single/simple-join queries. These are
-- the building blocks that advanced_queries.sql and analytics.sql compose
-- into multi-step analysis. Every query here targets a real business
-- question, not a bare syntax demo.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- SECTION 1: FILTERING
--------------------------------------------------------------------------------

-- Restaurants located in a specific city
SELECT RESTAURANT_ID, NAME, AREA, RATING
FROM   RESTAURANT
WHERE  CITY = 'Ahmedabad';

-- Menu items priced above a given threshold (e.g. premium items)
SELECT ITEM_ID, MENU_ID, ITEM_NAME, PRICE
FROM   MENU_ITEM
WHERE  PRICE > 300;

-- Customers whose name matches a search pattern (typical "search customer" UI need)
SELECT CUSTOMER_ID, FULL_NAME, EMAIL, PHONE
FROM   CUSTOMER
WHERE  FULL_NAME LIKE 'A%';

-- Customers by email domain
SELECT CUSTOMER_ID, FULL_NAME, EMAIL
FROM   CUSTOMER
WHERE  EMAIL LIKE '%@gmail.com';

-- All successfully delivered orders
SELECT ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, ORDER_DATE, TOTAL_AMOUNT
FROM   ORDERS
WHERE  ORDER_STATUS = 'DELIVERED';

-- Orders placed within a specific date range
SELECT ORDER_ID, CUSTOMER_ID, ORDER_DATE, TOTAL_AMOUNT, ORDER_STATUS
FROM   ORDERS
WHERE  ORDER_DATE BETWEEN TO_DATE('2026-01-01','YYYY-MM-DD')
                       AND TO_DATE('2026-03-31','YYYY-MM-DD');

-- Orders above a given value (high-value order lookup)
SELECT ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, TOTAL_AMOUNT
FROM   ORDERS
WHERE  TOTAL_AMOUNT > 1000;

-- Available menu items only (a real ordering screen would only show these)
SELECT ITEM_ID, MENU_ID, ITEM_NAME, PRICE
FROM   MENU_ITEM
WHERE  AVAILABLE_STATUS = 'YES';

--------------------------------------------------------------------------------
-- SECTION 2: SORTING
--------------------------------------------------------------------------------

-- Restaurants sorted by rating (best first), tie-broken alphabetically
SELECT RESTAURANT_ID, NAME, CITY, RATING
FROM   RESTAURANT
ORDER BY RATING DESC, NAME ASC;

-- A customer's orders, most recent and highest-value first
SELECT ORDER_ID, ORDER_DATE, TOTAL_AMOUNT, ORDER_STATUS
FROM   ORDERS
WHERE  CUSTOMER_ID = 1
ORDER BY ORDER_DATE DESC, TOTAL_AMOUNT DESC;

-- Menu items sorted cheapest to most expensive within a menu
SELECT ITEM_ID, ITEM_NAME, PRICE
FROM   MENU_ITEM
WHERE  MENU_ID = 1
ORDER BY PRICE ASC;

--------------------------------------------------------------------------------
-- SECTION 3: BASIC JOINS (one relationship at a time)
--------------------------------------------------------------------------------

-- CUSTOMER -> ORDERS: a customer's order history
SELECT c.CUSTOMER_ID, c.FULL_NAME, o.ORDER_ID, o.ORDER_DATE, o.TOTAL_AMOUNT
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  c.CUSTOMER_ID = 1
ORDER BY o.ORDER_DATE;

-- RESTAURANT -> ORDERS: orders received by one restaurant
SELECT r.RESTAURANT_ID, r.NAME, o.ORDER_ID, o.ORDER_DATE, o.TOTAL_AMOUNT
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
WHERE  r.RESTAURANT_ID = 1
ORDER BY o.ORDER_DATE;

-- MENU -> MENU_ITEM: full menu listing for a restaurant's menu
SELECT m.MENU_ID, m.MENU_NAME, mi.ITEM_NAME, mi.PRICE, mi.AVAILABLE_STATUS
FROM   MENU m
JOIN   MENU_ITEM mi ON mi.MENU_ID = m.MENU_ID
WHERE  m.MENU_ID = 1
ORDER BY mi.PRICE;

-- ORDERS -> ORDER_ITEM: line items for one order
SELECT o.ORDER_ID, oi.ITEM_ID, oi.QUANTITY, oi.PRICE, (oi.QUANTITY * oi.PRICE) AS LINE_TOTAL
FROM   ORDERS o
JOIN   ORDER_ITEM oi ON oi.ORDER_ID = o.ORDER_ID
WHERE  o.ORDER_ID = 1;

-- ORDERS -> PAYMENT: payment status for a set of orders
SELECT o.ORDER_ID, o.TOTAL_AMOUNT, p.PAYMENT_MODE, p.PAYMENT_STATUS
FROM   ORDERS o
JOIN   PAYMENT p ON p.ORDER_ID = o.ORDER_ID
WHERE  o.CUSTOMER_ID = 1;

-- ORDERS -> REVIEW: reviews left for a customer's orders (REVIEW no longer
-- stores CUSTOMER_ID directly since Phase 4 -- this join is how you reach it)
SELECT o.ORDER_ID, o.ORDER_DATE, rv.RATING, rv.COMMENTS
FROM   ORDERS o
JOIN   REVIEW rv ON rv.ORDER_ID = o.ORDER_ID
WHERE  o.CUSTOMER_ID = 1;

-- CUSTOMER -> ADDRESS: all saved addresses for a customer
SELECT c.CUSTOMER_ID, c.FULL_NAME, a.ADDRESS_ID, a.HOUSE_NO, a.STREET, a.CITY, a.ADDRESS_TYPE
FROM   CUSTOMER c
JOIN   ADDRESS a ON a.CUSTOMER_ID = c.CUSTOMER_ID
WHERE  c.CUSTOMER_ID = 1;

-- Multi-table join: a fully readable order summary line
-- (CUSTOMER -> ORDERS -> RESTAURANT -> ADDRESS; needs 4 tables because the
-- order itself only stores foreign keys, not the human-readable names)
SELECT o.ORDER_ID,
       c.FULL_NAME    AS CUSTOMER_NAME,
       r.NAME          AS RESTAURANT_NAME,
       a.CITY          AS DELIVERY_CITY,
       o.ORDER_DATE,
       o.TOTAL_AMOUNT,
       o.ORDER_STATUS
FROM   ORDERS o
JOIN   CUSTOMER c   ON c.CUSTOMER_ID = o.CUSTOMER_ID
JOIN   RESTAURANT r ON r.RESTAURANT_ID = o.RESTAURANT_ID
JOIN   ADDRESS a    ON a.ADDRESS_ID = o.ADDRESS_ID
ORDER BY o.ORDER_DATE DESC
FETCH FIRST 20 ROWS ONLY;

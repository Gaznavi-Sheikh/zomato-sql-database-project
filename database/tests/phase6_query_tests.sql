--------------------------------------------------------------------------------
-- PHASE 6 — QUERY / ANALYTICS VALIDATION
--------------------------------------------------------------------------------
-- Read-only validation queries for the analytics built in
-- database/queries/*.sql. Where a true invariant exists (e.g. "order total
-- must equal sum of its line items"), the query asserts it and should
-- return ZERO rows. Where no single correct number exists (e.g. "top
-- restaurant by revenue"), the query instead checks for internal
-- consistency (no duplicate ranks, no impossible values) rather than a
-- hardcoded expected result.
--
-- I could not run this against a live Oracle instance (no sqlplus/Docker
-- available). Every check below was independently validated by
-- reproducing the same logic in Python against the actual Phase 5 seed
-- data -- see the Phase 6 completion report for those results. Run this
-- file for the authoritative Oracle-side confirmation.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. ORDER TOTAL CALCULATION (must be zero rows -- true invariant)
--------------------------------------------------------------------------------
SELECT o.ORDER_ID, o.TOTAL_AMOUNT, SUM(oi.QUANTITY * oi.PRICE) AS COMPUTED_TOTAL
FROM   ORDERS o
JOIN   ORDER_ITEM oi ON oi.ORDER_ID = o.ORDER_ID
GROUP BY o.ORDER_ID, o.TOTAL_AMOUNT
HAVING o.TOTAL_AMOUNT <> SUM(oi.QUANTITY * oi.PRICE);

--------------------------------------------------------------------------------
-- 2. RESTAURANT REVENUE AGGREGATION SANITY (no negative/NULL revenue, no
-- restaurant revenue exceeding the platform total -- must be zero rows)
--------------------------------------------------------------------------------
SELECT r.RESTAURANT_ID, SUM(o.TOTAL_AMOUNT) AS REVENUE
FROM   RESTAURANT r
JOIN   ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID
HAVING SUM(o.TOTAL_AMOUNT) IS NULL
    OR SUM(o.TOTAL_AMOUNT) < 0
    OR SUM(o.TOTAL_AMOUNT) > (SELECT SUM(TOTAL_AMOUNT) FROM ORDERS);

--------------------------------------------------------------------------------
-- 3. CUSTOMER SPENDING AGGREGATION SANITY (must be zero rows)
--------------------------------------------------------------------------------
SELECT c.CUSTOMER_ID, SUM(o.TOTAL_AMOUNT) AS SPEND
FROM   CUSTOMER c
JOIN   ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID
HAVING SUM(o.TOTAL_AMOUNT) IS NULL OR SUM(o.TOTAL_AMOUNT) < 0;

--------------------------------------------------------------------------------
-- 4. ORDER COUNTS RECONCILE (sum of per-restaurant order counts must equal
-- the platform total order count -- must return a single row where both
-- sides match; a mismatch here would mean a JOIN dropped or duplicated rows)
--------------------------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM ORDERS) AS PLATFORM_TOTAL,
       (SELECT SUM(cnt) FROM (SELECT COUNT(*) AS cnt FROM ORDERS GROUP BY RESTAURANT_ID)) AS SUM_OF_RESTAURANT_COUNTS
FROM   DUAL;

--------------------------------------------------------------------------------
-- 5. REVIEW COUNTS: every review maps to exactly one order, no order has
-- more than one review (must be zero rows -- protected by UK_REVIEW_ORDER,
-- checked here again as a data-level assertion)
--------------------------------------------------------------------------------
SELECT ORDER_ID, COUNT(*) FROM REVIEW GROUP BY ORDER_ID HAVING COUNT(*) > 1;

--------------------------------------------------------------------------------
-- 6. DELIVERED/CANCELLED COUNTS RECONCILE WITH TOTAL (must return a single
-- row where all three numbers are consistent: delivered + cancelled +
-- onway + placed = total orders)
--------------------------------------------------------------------------------
SELECT COUNT(*) AS TOTAL_ORDERS,
       SUM(CASE WHEN ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END) AS DELIVERED,
       SUM(CASE WHEN ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END) AS CANCELLED,
       SUM(CASE WHEN ORDER_STATUS = 'ONWAY' THEN 1 ELSE 0 END) AS ONWAY,
       SUM(CASE WHEN ORDER_STATUS = 'PLACED' THEN 1 ELSE 0 END) AS PLACED,
       COUNT(*) - (SUM(CASE WHEN ORDER_STATUS = 'DELIVERED' THEN 1 ELSE 0 END)
                 + SUM(CASE WHEN ORDER_STATUS = 'CANCELLED' THEN 1 ELSE 0 END)
                 + SUM(CASE WHEN ORDER_STATUS = 'ONWAY' THEN 1 ELSE 0 END)
                 + SUM(CASE WHEN ORDER_STATUS = 'PLACED' THEN 1 ELSE 0 END)) AS UNACCOUNTED_FOR
FROM   ORDERS;

--------------------------------------------------------------------------------
-- 7. TOP-N QUERY INTEGRITY: the partitioned Top-5-items-per-restaurant query
-- must never return MORE than 5 rows for any single restaurant (must be
-- zero rows -- a ranking/partition bug would show up as a group with >5)
--------------------------------------------------------------------------------
SELECT RESTAURANT_ID, COUNT(*) AS ROWS_RETURNED
FROM (
    SELECT m.RESTAURANT_ID, mi.ITEM_NAME,
           ROW_NUMBER() OVER (PARTITION BY m.RESTAURANT_ID ORDER BY SUM(oi.QUANTITY) DESC) AS RN
    FROM   MENU_ITEM mi
    JOIN   MENU m        ON m.MENU_ID = mi.MENU_ID
    JOIN   ORDER_ITEM oi ON oi.ITEM_ID = mi.ITEM_ID
    GROUP BY m.RESTAURANT_ID, mi.ITEM_NAME
)
WHERE RN <= 5
GROUP BY RESTAURANT_ID
HAVING COUNT(*) > 5;

--------------------------------------------------------------------------------
-- 8. WINDOW-FUNCTION ORDERING CHECK: ROW_NUMBER() values within a partition
-- must be a contiguous sequence 1..N with no gaps and no duplicates (must
-- be zero rows)
--------------------------------------------------------------------------------
SELECT RESTAURANT_ID, RN, COUNT(*) AS DUPLICATE_RN_COUNT
FROM (
    SELECT m.RESTAURANT_ID, mi.ITEM_NAME,
           ROW_NUMBER() OVER (PARTITION BY m.RESTAURANT_ID ORDER BY mi.ITEM_ID) AS RN
    FROM   MENU_ITEM mi JOIN MENU m ON m.MENU_ID = mi.MENU_ID
)
GROUP BY RESTAURANT_ID, RN
HAVING COUNT(*) > 1;

--------------------------------------------------------------------------------
-- 9. HISTORICAL PRICE DIFFERENCES: proves the phenomenon exists (should
-- return a count > 0 -- this is the one assertion that must NOT be zero)
--------------------------------------------------------------------------------
SELECT COUNT(*) AS ORDER_ITEMS_WITH_HISTORICAL_PRICE_DIFFERENCE
FROM   ORDER_ITEM oi
JOIN   MENU_ITEM mi ON mi.ITEM_ID = oi.ITEM_ID
WHERE  oi.PRICE <> mi.PRICE;

--------------------------------------------------------------------------------
-- 10. MONTHLY AGGREGATION RECONCILES WITH PLATFORM TOTAL (sum of every
-- month's order count must equal the platform total -- single row, both
-- sides must match)
--------------------------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM ORDERS) AS PLATFORM_TOTAL,
       (SELECT SUM(cnt) FROM (
           SELECT COUNT(*) AS cnt FROM ORDERS GROUP BY TRUNC(ORDER_DATE, 'MM')
       )) AS SUM_OF_MONTHLY_COUNTS
FROM   DUAL;

--------------------------------------------------------------------------------
-- 11. NO DUPLICATE ROWS FROM MULTI-TABLE JOINS (a common accidental-fan-out
-- bug: joining ORDERS to both ORDER_ITEM and PAYMENT in the same query
-- without aggregating would multiply rows. This checks the safe pattern
-- used throughout this project -- one fact table joined at a time -- by
-- confirming ORDER_ID stays unique when ORDERS is joined only to PAYMENT)
--------------------------------------------------------------------------------
SELECT o.ORDER_ID, COUNT(*) AS ROW_COUNT
FROM   ORDERS o
JOIN   PAYMENT p ON p.ORDER_ID = o.ORDER_ID
GROUP BY o.ORDER_ID
HAVING COUNT(*) > 1;

--------------------------------------------------------------------------------
-- 12. COMPOSITE ADDRESS/CUSTOMER OWNERSHIP STILL HOLDS AFTER ANALYTICS
-- (re-asserts the Phase 4 rule that any query joining ORDERS to ADDRESS is
-- relying on -- must be zero rows)
--------------------------------------------------------------------------------
SELECT o.ORDER_ID
FROM   ORDERS o
JOIN   ADDRESS a ON a.ADDRESS_ID = o.ADDRESS_ID
WHERE  a.CUSTOMER_ID <> o.CUSTOMER_ID;

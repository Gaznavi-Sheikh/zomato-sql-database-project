--------------------------------------------------------------------------------
-- PHASE 5 — SEED DATA VALIDATION
--------------------------------------------------------------------------------
-- Reusable, read-only validation queries for the expanded dataset. Every
-- query here should return ZERO rows (for orphan/mismatch/duplicate
-- checks) or a sensible summary (for the count/distribution queries).
-- Nothing here modifies data. Run after 01_tables.sql -> 02_constraints.sql
-- -> seed/01_seed_data.sql have all executed successfully.
--
-- I could not run these against a live Oracle instance in this environment
-- (no sqlplus, no Docker available) — these queries were validated by
-- reproducing their logic in Python against the actual generated seed
-- file (see docs/seed-data.md for the results). Run them here for the
-- authoritative Oracle-side confirmation.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. ROW COUNTS BY TABLE
--------------------------------------------------------------------------------
SELECT 'RESTAURANT' tbl, COUNT(*) rows_ FROM RESTAURANT UNION ALL
SELECT 'CATEGORY', COUNT(*) FROM CATEGORY UNION ALL
SELECT 'RESTAURANT_CATEGORY', COUNT(*) FROM RESTAURANT_CATEGORY UNION ALL
SELECT 'MENU', COUNT(*) FROM MENU UNION ALL
SELECT 'MENU_ITEM', COUNT(*) FROM MENU_ITEM UNION ALL
SELECT 'CUSTOMER', COUNT(*) FROM CUSTOMER UNION ALL
SELECT 'ADDRESS', COUNT(*) FROM ADDRESS UNION ALL
SELECT 'DELIVERY_PERSON', COUNT(*) FROM DELIVERY_PERSON UNION ALL
SELECT 'ORDERS', COUNT(*) FROM ORDERS UNION ALL
SELECT 'ORDER_ITEM', COUNT(*) FROM ORDER_ITEM UNION ALL
SELECT 'PAYMENT', COUNT(*) FROM PAYMENT UNION ALL
SELECT 'REVIEW', COUNT(*) FROM REVIEW;

--------------------------------------------------------------------------------
-- 2. ORPHAN DETECTION (each should return 0 rows)
--------------------------------------------------------------------------------
-- RESTAURANT_CATEGORY orphans
SELECT * FROM RESTAURANT_CATEGORY rc
WHERE NOT EXISTS (SELECT 1 FROM RESTAURANT r WHERE r.RESTAURANT_ID = rc.RESTAURANT_ID)
   OR NOT EXISTS (SELECT 1 FROM CATEGORY c WHERE c.CATEGORY_ID = rc.CATEGORY_ID);

-- MENU orphans (no matching restaurant)
SELECT * FROM MENU m
WHERE NOT EXISTS (SELECT 1 FROM RESTAURANT r WHERE r.RESTAURANT_ID = m.RESTAURANT_ID);

-- MENU_ITEM orphans (no matching menu)
SELECT * FROM MENU_ITEM mi
WHERE NOT EXISTS (SELECT 1 FROM MENU m WHERE m.MENU_ID = mi.MENU_ID);

-- ADDRESS orphans (no matching customer)
SELECT * FROM ADDRESS a
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER c WHERE c.CUSTOMER_ID = a.CUSTOMER_ID);

-- ORDERS orphans (customer / restaurant / non-null delivery person)
SELECT * FROM ORDERS o
WHERE NOT EXISTS (SELECT 1 FROM CUSTOMER c WHERE c.CUSTOMER_ID = o.CUSTOMER_ID)
   OR NOT EXISTS (SELECT 1 FROM RESTAURANT r WHERE r.RESTAURANT_ID = o.RESTAURANT_ID)
   OR (o.DELIVERY_ID IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM DELIVERY_PERSON d WHERE d.DELIVERY_ID = o.DELIVERY_ID));

-- ORDERS: address must belong to the SAME customer as the order (composite rule)
SELECT o.ORDER_ID, o.CUSTOMER_ID, o.ADDRESS_ID
FROM ORDERS o
WHERE NOT EXISTS (
    SELECT 1 FROM ADDRESS a
    WHERE a.ADDRESS_ID = o.ADDRESS_ID AND a.CUSTOMER_ID = o.CUSTOMER_ID
);

-- ORDER_ITEM orphans
SELECT * FROM ORDER_ITEM oi
WHERE NOT EXISTS (SELECT 1 FROM ORDERS o WHERE o.ORDER_ID = oi.ORDER_ID)
   OR NOT EXISTS (SELECT 1 FROM MENU_ITEM mi WHERE mi.ITEM_ID = oi.ITEM_ID);

-- PAYMENT orphans
SELECT * FROM PAYMENT p
WHERE NOT EXISTS (SELECT 1 FROM ORDERS o WHERE o.ORDER_ID = p.ORDER_ID);

-- REVIEW orphans (also proves every review points at a real order)
SELECT * FROM REVIEW rv
WHERE NOT EXISTS (SELECT 1 FROM ORDERS o WHERE o.ORDER_ID = rv.ORDER_ID);

--------------------------------------------------------------------------------
-- 3. DUPLICATE DETECTION (each should return 0 rows)
--------------------------------------------------------------------------------
-- Duplicate PAYMENT per order (should be impossible given UK_PAYMENT_ORDER,
-- included here as a defense-in-depth data check)
SELECT ORDER_ID, COUNT(*) FROM PAYMENT GROUP BY ORDER_ID HAVING COUNT(*) > 1;

-- Duplicate REVIEW per order
SELECT ORDER_ID, COUNT(*) FROM REVIEW GROUP BY ORDER_ID HAVING COUNT(*) > 1;

-- Duplicate RESTAURANT_CATEGORY pairs
SELECT RESTAURANT_ID, CATEGORY_ID, COUNT(*)
FROM RESTAURANT_CATEGORY GROUP BY RESTAURANT_ID, CATEGORY_ID HAVING COUNT(*) > 1;

--------------------------------------------------------------------------------
-- 4. ORDERS WITHOUT ITEMS (should return 0 rows — every order must have >=1 line item)
--------------------------------------------------------------------------------
SELECT o.ORDER_ID
FROM ORDERS o
WHERE NOT EXISTS (SELECT 1 FROM ORDER_ITEM oi WHERE oi.ORDER_ID = o.ORDER_ID);

--------------------------------------------------------------------------------
-- 5. ORDERS WITHOUT PAYMENTS (expected: a real, non-zero set — only
-- CANCELLED orders may lack a payment, representing a cancelled-before-
-- payment scenario; any other status here would be a real data problem)
--------------------------------------------------------------------------------
SELECT o.ORDER_STATUS, COUNT(*) AS orders_without_payment
FROM ORDERS o
WHERE NOT EXISTS (SELECT 1 FROM PAYMENT p WHERE p.ORDER_ID = o.ORDER_ID)
GROUP BY o.ORDER_STATUS;

--------------------------------------------------------------------------------
-- 6. REVIEWS ON NON-DELIVERED ORDERS (should return 0 rows — a review only
-- makes sense for a completed order)
--------------------------------------------------------------------------------
SELECT rv.REVIEW_ID, rv.ORDER_ID, o.ORDER_STATUS
FROM REVIEW rv
JOIN ORDERS o ON o.ORDER_ID = rv.ORDER_ID
WHERE o.ORDER_STATUS <> 'DELIVERED';

--------------------------------------------------------------------------------
-- 7. ORDER-TOTAL MISMATCHES (should return 0 rows)
--------------------------------------------------------------------------------
SELECT o.ORDER_ID, o.TOTAL_AMOUNT, SUM(oi.QUANTITY * oi.PRICE) AS computed_total
FROM ORDERS o
JOIN ORDER_ITEM oi ON oi.ORDER_ID = o.ORDER_ID
GROUP BY o.ORDER_ID, o.TOTAL_AMOUNT
HAVING o.TOTAL_AMOUNT <> SUM(oi.QUANTITY * oi.PRICE);

--------------------------------------------------------------------------------
-- 8. PAYMENT AMOUNT VS ORDER TOTAL MISMATCHES (should return 0 rows)
--------------------------------------------------------------------------------
SELECT p.ORDER_ID, p.AMOUNT, o.TOTAL_AMOUNT
FROM PAYMENT p
JOIN ORDERS o ON o.ORDER_ID = p.ORDER_ID
WHERE p.AMOUNT <> o.TOTAL_AMOUNT;

--------------------------------------------------------------------------------
-- 9. MENU ITEMS WITHOUT MENUS / RESTAURANTS WITHOUT MENUS (should be 0 rows)
--------------------------------------------------------------------------------
SELECT mi.* FROM MENU_ITEM mi
WHERE NOT EXISTS (SELECT 1 FROM MENU m WHERE m.MENU_ID = mi.MENU_ID);

SELECT r.RESTAURANT_ID, r.NAME
FROM RESTAURANT r
WHERE NOT EXISTS (SELECT 1 FROM MENU m WHERE m.RESTAURANT_ID = r.RESTAURANT_ID);

--------------------------------------------------------------------------------
-- 10. HISTORICAL PRICE SNAPSHOT PROOF: order items whose price at order
-- time differs from the item's CURRENT menu price (expected: a real,
-- non-trivial set — this is the whole point of ORDER_ITEM.PRICE existing)
--------------------------------------------------------------------------------
SELECT oi.ORDER_ID, oi.ITEM_ID, mi.ITEM_NAME, oi.PRICE AS price_at_order_time,
       mi.PRICE AS current_menu_price
FROM ORDER_ITEM oi
JOIN MENU_ITEM mi ON mi.ITEM_ID = oi.ITEM_ID
WHERE oi.PRICE <> mi.PRICE
FETCH FIRST 20 ROWS ONLY;

--------------------------------------------------------------------------------
-- 11. CUSTOMERS WITH MULTIPLE ADDRESSES / CUSTOMERS WITH NO ORDERS
--------------------------------------------------------------------------------
SELECT CUSTOMER_ID, COUNT(*) AS address_count
FROM ADDRESS GROUP BY CUSTOMER_ID HAVING COUNT(*) > 1
ORDER BY address_count DESC;

SELECT c.CUSTOMER_ID, c.FULL_NAME
FROM CUSTOMER c
WHERE NOT EXISTS (SELECT 1 FROM ORDERS o WHERE o.CUSTOMER_ID = c.CUSTOMER_ID);

--------------------------------------------------------------------------------
-- 12. RESTAURANTS WITH ORDER COUNTS / CUSTOMERS WITH ORDER COUNTS
--------------------------------------------------------------------------------
SELECT r.RESTAURANT_ID, r.NAME, COUNT(o.ORDER_ID) AS order_count
FROM RESTAURANT r
LEFT JOIN ORDERS o ON o.RESTAURANT_ID = r.RESTAURANT_ID
GROUP BY r.RESTAURANT_ID, r.NAME
ORDER BY order_count DESC;

SELECT c.CUSTOMER_ID, c.FULL_NAME, COUNT(o.ORDER_ID) AS order_count
FROM CUSTOMER c
LEFT JOIN ORDERS o ON o.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.FULL_NAME
ORDER BY order_count DESC;

--------------------------------------------------------------------------------
-- 13. ORDER STATUS / REVIEW RATING DISTRIBUTIONS (sanity check on realism)
--------------------------------------------------------------------------------
SELECT ORDER_STATUS, COUNT(*) FROM ORDERS GROUP BY ORDER_STATUS ORDER BY 2 DESC;

SELECT RATING, COUNT(*) FROM REVIEW GROUP BY RATING ORDER BY RATING DESC;

--------------------------------------------------------------------------------
-- 14. ORDER DATE RANGE / MONTHLY VOLUME (proves orders aren't all on one day)
--------------------------------------------------------------------------------
SELECT MIN(ORDER_DATE) AS earliest_order, MAX(ORDER_DATE) AS latest_order,
       COUNT(DISTINCT TRUNC(ORDER_DATE, 'MM')) AS distinct_months
FROM ORDERS;

SELECT TO_CHAR(ORDER_DATE, 'YYYY-MM') AS month, COUNT(*) AS order_count
FROM ORDERS
GROUP BY TO_CHAR(ORDER_DATE, 'YYYY-MM')
ORDER BY month;

--------------------------------------------------------------------------------
-- PHASE 3 — CONSTRAINT VALIDATION TESTS
--------------------------------------------------------------------------------
-- Purpose: prove the constraints in 02_constraints.sql actually reject
-- invalid data. Every INSERT below is EXPECTED TO FAIL with the noted
-- Oracle error code. Nothing here is ever committed, and every test ends
-- with ROLLBACK, so no residue is left even if a statement unexpectedly
-- succeeds.
--
-- Run order: 01_tables.sql -> 02_constraints.sql -> seed/01_seed_data.sql
-- -> this file. Several tests rely on rows already present from the seed
-- data (e.g. CATEGORY_ID 1, CUSTOMER_ID 1's email, ORDER_ID 1's payment).
--
-- Each test uses a fresh, unused ID for the row it's inserting so that
-- the ONE constraint under test is what actually fires — not an
-- unrelated PK collision. Where a test needs a row that doesn't yet
-- exist (e.g. an order with no payment yet), that setup row is inserted
-- first, in the same test block, before the ROLLBACK.
--------------------------------------------------------------------------------

-- TEST 1 — Duplicate CATEGORY_ID
-- Expected: ORA-00001 (unique constraint PK_CATEGORY violated)
INSERT INTO CATEGORY VALUES (1, 'Duplicate Category', 'Should fail');
ROLLBACK;

-- TEST 2 — Duplicate CUSTOMER email (customer 1's email already exists)
-- Expected: ORA-00001 (unique constraint UK_CUSTOMER_EMAIL violated)
INSERT INTO CUSTOMER VALUES (999, 'Fake Customer', '9999999999', 'amit@gmail.com', 'M', SYSDATE);
ROLLBACK;

-- TEST 3 — RESTAURANT_CATEGORY referencing a RESTAURANT_ID that doesn't exist
-- Expected: ORA-02291 (FK_RESTAURANT_CATEGORY_RESTAURANT violated — parent key not found)
INSERT INTO RESTAURANT_CATEGORY VALUES (999, 1);
ROLLBACK;

-- TEST 4 — MENU referencing a RESTAURANT_ID that doesn't exist
-- Expected: ORA-02291 (FK_MENU_RESTAURANT violated — parent key not found)
INSERT INTO MENU VALUES (999, 999, 'Ghost Menu', SYSDATE);
ROLLBACK;

-- TEST 5 — ORDERS referencing a DELIVERY_ID that doesn't exist
-- Column order: (ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, ADDRESS_ID,
-- DELIVERY_ID, ORDER_DATE, TOTAL_AMOUNT, ORDER_STATUS) — updated in
-- Phase 4 to include ADDRESS_ID. ADDRESS_ID=1 belongs to CUSTOMER_ID=1,
-- so this row satisfies FK_ORDERS_ADDRESS and isolates the DELIVERY_ID FK.
-- Expected: ORA-02291 (FK_ORDERS_DELIVERY_PERSON violated — parent key not found)
INSERT INTO ORDERS VALUES (999, 1, 1, 1, 999, SYSDATE, 100, 'PLACED');
ROLLBACK;

-- TEST 6 — Second PAYMENT for an ORDER_ID that already has one (order 1 already
-- has payment_id 1)
-- Expected: ORA-00001 (unique constraint UK_PAYMENT_ORDER violated)
INSERT INTO PAYMENT VALUES (999, 1, 'CASH', SYSDATE, 100, 'SUCCESS');
ROLLBACK;

-- TEST 7 — REVIEW rating outside the allowed 1-5 range
-- Column order: (REVIEW_ID, ORDER_ID, RATING, COMMENTS, REVIEW_DATE) —
-- updated in Phase 4 (REVIEW now points at an ORDER, not directly at a
-- customer/restaurant pair). Every existing order 1-10 already has a
-- review, so a fresh order (997) is inserted first to isolate
-- CK_REVIEW_RATING rather than tripping UK_REVIEW_ORDER.
-- Expected: ORA-02290 (check constraint CK_REVIEW_RATING violated)
INSERT INTO ORDERS VALUES (997, 1, 1, 1, 1, SYSDATE, 100, 'PLACED');
INSERT INTO REVIEW VALUES (999, 997, 6, 'Should fail', SYSDATE);
ROLLBACK;

-- TEST 8 — Negative MENU_ITEM price
-- Expected: ORA-02290 (check constraint CK_MENU_ITEM_PRICE violated)
INSERT INTO MENU_ITEM VALUES (999, 1, 'Bad Item', -50, 'YES');
ROLLBACK;

-- TEST 9 — Zero ORDER_ITEM quantity (using a fresh (order, item) pair — (1,1)
-- already exists in seed data, which would trip PK_ORDER_ITEM instead of the
-- constraint this test is actually targeting)
-- Expected: ORA-02290 (check constraint CK_ORDER_ITEM_QUANTITY violated)
INSERT INTO ORDER_ITEM VALUES (2, 3, 0, 100);
ROLLBACK;

-- TEST 10 — Negative PAYMENT amount. A brand-new order (998) is inserted
-- first so this test isolates CK_PAYMENT_AMOUNT rather than tripping
-- UK_PAYMENT_ORDER (every existing 1-10 order already has a payment row).
-- Expected: ORA-02290 (check constraint CK_PAYMENT_AMOUNT violated)
INSERT INTO ORDERS VALUES (998, 1, 1, 1, 1, SYSDATE, 100, 'PLACED');
INSERT INTO PAYMENT VALUES (998, 998, 'UPI', SYSDATE, -100, 'PENDING');
ROLLBACK;

--------------------------------------------------------------------------------
-- ORACLE METADATA VERIFICATION (Step 15)
--------------------------------------------------------------------------------
-- I could not run these myself — there is no Oracle instance available in
-- this environment (no sqlplus, no Docker). Run these against your actual
-- database after setup and compare the results to the Phase 3 constraint
-- matrix in the completion report.
--------------------------------------------------------------------------------

-- All constraints, grouped by table and type
SELECT table_name, constraint_name, constraint_type, status
FROM   USER_CONSTRAINTS
WHERE  table_name IN (
           'RESTAURANT', 'CATEGORY', 'RESTAURANT_CATEGORY', 'MENU', 'MENU_ITEM',
           'CUSTOMER', 'ADDRESS', 'DELIVERY_PERSON', 'ORDERS', 'ORDER_ITEM',
           'PAYMENT', 'REVIEW')
ORDER BY table_name, constraint_type;

-- Columns participating in each constraint
SELECT constraint_name, column_name, position
FROM   USER_CONS_COLUMNS
WHERE  table_name IN (
           'RESTAURANT', 'CATEGORY', 'RESTAURANT_CATEGORY', 'MENU', 'MENU_ITEM',
           'CUSTOMER', 'ADDRESS', 'DELIVERY_PERSON', 'ORDERS', 'ORDER_ITEM',
           'PAYMENT', 'REVIEW')
ORDER BY constraint_name, position;

-- Column data types, precision, scale, nullability, defaults
SELECT table_name, column_name, data_type, data_length, data_precision,
       data_scale, nullable, data_default
FROM   USER_TAB_COLUMNS
WHERE  table_name IN (
           'RESTAURANT', 'CATEGORY', 'RESTAURANT_CATEGORY', 'MENU', 'MENU_ITEM',
           'CUSTOMER', 'ADDRESS', 'DELIVERY_PERSON', 'ORDERS', 'ORDER_ITEM',
           'PAYMENT', 'REVIEW')
ORDER BY table_name, column_id;

-- Orphan check: RESTAURANT_CATEGORY rows whose RESTAURANT_ID has no match
-- (should return 0 rows once the FK is enforced)
SELECT rc.*
FROM   RESTAURANT_CATEGORY rc
WHERE  NOT EXISTS (SELECT 1 FROM RESTAURANT r WHERE r.RESTAURANT_ID = rc.RESTAURANT_ID);

-- Orphan check: ORDERS rows whose DELIVERY_ID doesn't exist in DELIVERY_PERSON
-- (NULL DELIVERY_ID is excluded deliberately — that's a legitimate
-- not-yet-assigned order, not an orphan)
SELECT o.*
FROM   ORDERS o
WHERE  o.DELIVERY_ID IS NOT NULL
AND    NOT EXISTS (SELECT 1 FROM DELIVERY_PERSON d WHERE d.DELIVERY_ID = o.DELIVERY_ID);

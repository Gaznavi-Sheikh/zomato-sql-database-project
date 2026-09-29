--------------------------------------------------------------------------------
-- PHASE 4 — NORMALIZATION / RELATIONSHIP VALIDATION TESTS
--------------------------------------------------------------------------------
-- Covers the two structural changes made in Phase 4: ORDERS.ADDRESS_ID
-- (with its composite FK to ADDRESS) and REVIEW.ORDER_ID (replacing
-- REVIEW.CUSTOMER_ID / REVIEW.RESTAURANT_ID). Same approach as
-- phase3_constraint_tests.sql: every INSERT below is expected to FAIL,
-- nothing is committed, and every test ends with ROLLBACK.
--
-- Run order: 01_tables.sql -> 02_constraints.sql -> seed/01_seed_data.sql
-- -> this file.
--------------------------------------------------------------------------------

-- TEST 1 — ORDERS referencing an ADDRESS that belongs to a DIFFERENT
-- customer. Customer 1 is placing the order, but ADDRESS_ID 2 belongs to
-- CUSTOMER_ID 2, not 1. A plain single-column FK to ADDRESS.ADDRESS_ID
-- would NOT catch this (address 2 genuinely exists) — this is exactly
-- what the composite FK (ADDRESS_ID, CUSTOMER_ID) exists to prevent.
-- Expected: ORA-02291 (FK_ORDERS_ADDRESS violated — parent key not found,
-- because no ADDRESS row has ADDRESS_ID=2 AND CUSTOMER_ID=1 together)
INSERT INTO ORDERS VALUES (996, 1, 1, 2, 1, SYSDATE, 100, 'PLACED');
ROLLBACK;

-- TEST 2 — ORDERS with no delivery address at all
-- Expected: ORA-01400 (NOT NULL constraint on ORDERS.ADDRESS_ID violated)
INSERT INTO ORDERS (ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, DELIVERY_ID, ORDER_DATE, TOTAL_AMOUNT, ORDER_STATUS)
VALUES (995, 1, 1, 1, SYSDATE, 100, 'PLACED');
ROLLBACK;

-- TEST 3 — Second REVIEW for an order that already has one (order 1
-- already has review 1 from seed data)
-- Expected: ORA-00001 (unique constraint UK_REVIEW_ORDER violated)
INSERT INTO REVIEW VALUES (994, 1, 5, 'Duplicate review attempt', SYSDATE);
ROLLBACK;

-- TEST 4 — REVIEW referencing an ORDER_ID that doesn't exist. Also proves
-- "only customers who actually ordered can review" is now enforced at the
-- database layer, not just assumed by application logic.
-- Expected: ORA-02291 (FK_REVIEW_ORDERS violated — parent key not found)
INSERT INTO REVIEW VALUES (993, 990, 5, 'Never actually ordered', SYSDATE);
ROLLBACK;

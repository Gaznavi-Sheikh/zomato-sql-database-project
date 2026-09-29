--------------------------------------------------------------------------------
-- ZOMATO DATABASE PROJECT — V2 SCHEMA: TABLE DEFINITIONS (Phase 3)
--------------------------------------------------------------------------------
-- This file defines table structure only: columns, Oracle data types,
-- NOT NULL, and DEFAULT. All relational constraints (PRIMARY KEY, FOREIGN
-- KEY, UNIQUE, CHECK) live in 02_constraints.sql, so this file can be
-- re-read on its own to see the shape of the data model without the
-- integrity rules layered on top.
--
-- Column-level NOT NULL is kept here (it's an intrinsic property of the
-- column, not a cross-table relational rule); PK/FK/UNIQUE/CHECK are not.
--
-- Data type corrections made in this phase (see Phase 3 audit for full
-- reasoning):
--   - VARCHAR -> VARCHAR2 everywhere (Oracle reserves plain VARCHAR for a
--     future, currently-undefined redefinition; VARCHAR2 is the only
--     correct choice in real Oracle code).
--   - PHONE columns (RESTAURANT, CUSTOMER, DELIVERY_PERSON): NUMBER ->
--     VARCHAR2(15). Phone numbers are identifiers, not quantities — you
--     never add or average them, and a NUMBER type silently drops a
--     leading zero or can't hold a "+" country-code prefix.
--   - ADDRESS.PINCODE: NUMBER(6) -> VARCHAR2(6). Same reasoning as phone:
--     a postal code is an identifier, and a leading-zero PIN code would
--     silently lose a digit if stored as NUMBER.
--   - Currency columns (MENU_ITEM.PRICE, ORDER_ITEM.PRICE,
--     ORDERS.TOTAL_AMOUNT, PAYMENT.AMOUNT): NUMBER(10) -> NUMBER(10,2).
--     Added decimal scale only — total precision (10 digits) is
--     unchanged, since headroom wasn't the identified problem, the
--     missing decimal places were.
--   - ORDER_ITEM.QUANTITY: NUMBER(10) -> NUMBER(4). A single order line's
--     quantity realistically never exceeds a few hundred; NUMBER(4)
--     (max 9999) is generous and self-documents intent, unlike a
--     10-digit field that could theoretically hold ten billion.
--   - RESTAURANT.RATING: VARCHAR2(10) -> NUMBER(2,1). This is a Phase 3
--     TYPE fix only. Whether this column should exist at all (since it
--     may be a derived/cached average of REVIEW.RATING) is an explicitly
--     DEFERRED Phase 4 normalization question — not decided here.
--
-- CREATED_DATE / REGISTRATION_DATE / ORDER_DATE / PAYMENT_DATE /
-- REVIEW_DATE all default to SYSDATE because each represents "when this
-- record was created," which is a safe, automatic default. This is
-- distinct from a business-meaningful date a user would ever want to
-- override (none of these columns are that in the current model).
-- MENU.CREATED_DATE now also defaults to SYSDATE for consistency with
-- every other *_DATE column — it had no default in V1, which was an
-- unexplained inconsistency, not a deliberate design choice.
--
-- PHASE 4 (normalization) STRUCTURAL CHANGES — see docs/normalization.md
-- for the full analysis:
--   - ORDERS gains ADDRESS_ID (NOT NULL). V1/V3 had no way to record which
--     of a customer's saved addresses an order was delivered to. A
--     composite FK in 02_constraints.sql (ADDRESS_ID, CUSTOMER_ID) ->
--     ADDRESS(ADDRESS_ID, CUSTOMER_ID) guarantees the referenced address
--     actually belongs to the ordering customer.
--   - REVIEW.CUSTOMER_ID and REVIEW.RESTAURANT_ID are replaced by
--     REVIEW.ORDER_ID. Keeping all three would create a transitive
--     dependency (REVIEW_ID -> ORDER_ID -> CUSTOMER_ID/RESTAURANT_ID) —
--     a real 3NF violation, since both are already derivable via ORDERS.
--     This also only allows reviewing an order that actually happened,
--     and (via a UNIQUE constraint) one review per order rather than one
--     review per customer-restaurant pair for life.
--------------------------------------------------------------------------------

-- 1. RESTAURANT TABLE
CREATE TABLE RESTAURANT (
    RESTAURANT_ID   NUMBER(5)      NOT NULL,
    NAME            VARCHAR2(20)   NOT NULL,
    PHONE           VARCHAR2(15)   NOT NULL,
    EMAIL           VARCHAR2(30)   NOT NULL,
    CITY            VARCHAR2(20)   NOT NULL,
    AREA            VARCHAR2(30),
    RATING          NUMBER(2,1),
    CREATED_DATE    DATE DEFAULT SYSDATE
);

-- 2. CATEGORY TABLE
CREATE TABLE CATEGORY (
    CATEGORY_ID     NUMBER(5)      NOT NULL,
    CATEGORY_NAME   VARCHAR2(30)   NOT NULL,
    DESCRIPTION     VARCHAR2(80)
);

-- 3. RESTAURANT_CATEGORY TABLE (many-to-many junction: RESTAURANT <-> CATEGORY)
CREATE TABLE RESTAURANT_CATEGORY (
    RESTAURANT_ID   NUMBER(5) NOT NULL,
    CATEGORY_ID     NUMBER(5) NOT NULL
);

-- 4. MENU TABLE
CREATE TABLE MENU (
    MENU_ID         NUMBER(5)      NOT NULL,
    RESTAURANT_ID   NUMBER(5)      NOT NULL,
    MENU_NAME       VARCHAR2(30)   NOT NULL,
    CREATED_DATE    DATE DEFAULT SYSDATE
);

-- 5. MENU_ITEM TABLE
CREATE TABLE MENU_ITEM (
    ITEM_ID             NUMBER(5)      NOT NULL,
    MENU_ID             NUMBER(5)      NOT NULL,
    ITEM_NAME           VARCHAR2(30)   NOT NULL,
    PRICE               NUMBER(10,2)   NOT NULL,
    AVAILABLE_STATUS    VARCHAR2(5) DEFAULT 'YES'
);

-- 6. CUSTOMER TABLE
CREATE TABLE CUSTOMER (
    CUSTOMER_ID         NUMBER(5)      NOT NULL,
    FULL_NAME           VARCHAR2(30)   NOT NULL,
    PHONE               VARCHAR2(15)   NOT NULL,
    EMAIL               VARCHAR2(30)   NOT NULL,
    GENDER              CHAR(1),
    REGISTRATION_DATE   DATE DEFAULT SYSDATE
);

-- 7. ADDRESS TABLE
CREATE TABLE ADDRESS (
    ADDRESS_ID      NUMBER(5)      NOT NULL,
    CUSTOMER_ID     NUMBER(5)      NOT NULL,
    HOUSE_NO        VARCHAR2(5),
    STREET          VARCHAR2(20),
    CITY            VARCHAR2(20),
    PINCODE         VARCHAR2(6),
    ADDRESS_TYPE    VARCHAR2(10)
);

-- 8. DELIVERY_PERSON TABLE
CREATE TABLE DELIVERY_PERSON (
    DELIVERY_ID     NUMBER(5)      NOT NULL,
    NAME            VARCHAR2(30)   NOT NULL,
    PHONE           VARCHAR2(15)   NOT NULL,
    VEHICLE_NO      VARCHAR2(15),
    STATUS          CHAR(10) DEFAULT 'AVAILABLE'
);

-- 9. ORDERS TABLE
-- TOTAL_AMOUNT is an intentionally denormalized cached aggregate (should
-- equal SUM(ORDER_ITEM.QUANTITY * PRICE) for this order) — same rationale
-- as RESTAURANT.RATING: avoids a join+SUM on every order-history read.
-- Keeping it in sync is a future (Phase 6+) trigger/application concern,
-- not resolved in Phase 4.
CREATE TABLE ORDERS (
    ORDER_ID        NUMBER(5)      NOT NULL,
    CUSTOMER_ID     NUMBER(5)      NOT NULL,
    RESTAURANT_ID   NUMBER(5)      NOT NULL,
    ADDRESS_ID      NUMBER(5)      NOT NULL,
    DELIVERY_ID     NUMBER(5),
    ORDER_DATE      DATE DEFAULT SYSDATE,
    TOTAL_AMOUNT    NUMBER(10,2),
    ORDER_STATUS    VARCHAR2(15) DEFAULT 'PLACED'
);

-- 10. ORDER_ITEM TABLE
-- PRICE intentionally duplicates MENU_ITEM.PRICE. This is a deliberate
-- price-at-order-time snapshot, not redundant data: menu prices change
-- over time, and a past order's total must not silently shift if the
-- restaurant later reprices an item.
CREATE TABLE ORDER_ITEM (
    ORDER_ID    NUMBER(5)      NOT NULL,
    ITEM_ID     NUMBER(5)      NOT NULL,
    QUANTITY    NUMBER(4)      NOT NULL,
    PRICE       NUMBER(10,2)   NOT NULL
);

-- 11. PAYMENT TABLE
CREATE TABLE PAYMENT (
    PAYMENT_ID      NUMBER(5)      NOT NULL,
    ORDER_ID        NUMBER(5)      NOT NULL,
    PAYMENT_MODE    VARCHAR2(5)    NOT NULL,
    PAYMENT_DATE    DATE DEFAULT SYSDATE,
    AMOUNT          NUMBER(10,2)   NOT NULL,
    PAYMENT_STATUS  VARCHAR2(10) DEFAULT 'PENDING' NOT NULL
);

-- 12. REVIEW TABLE
-- A review now rates a specific ORDER, not a customer-restaurant pair in
-- the abstract (see docs/normalization.md, Deep Dive 3). CUSTOMER_ID and
-- RESTAURANT_ID are still fully queryable via a join through ORDERS.
CREATE TABLE REVIEW (
    REVIEW_ID       NUMBER(5)      NOT NULL,
    ORDER_ID        NUMBER(5)      NOT NULL,
    RATING          NUMBER(1)      NOT NULL,
    COMMENTS        VARCHAR2(50),
    REVIEW_DATE     DATE DEFAULT SYSDATE
);

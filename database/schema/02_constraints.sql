--------------------------------------------------------------------------------
-- ZOMATO DATABASE PROJECT — SCHEMA CONSTRAINTS (Phase 3, updated Phase 4)
--------------------------------------------------------------------------------
-- Run this AFTER 01_tables.sql and BEFORE seed/01_seed_data.sql.
--
-- Section order is PK -> UNIQUE -> FOREIGN KEY -> CHECK. This is a Phase 4
-- correction from the Phase 3 file, which ordered FK before UNIQUE: that
-- happened to work then because every FK referenced a PK column, but the
-- new ORDERS -> ADDRESS composite FK (added in Phase 4) targets a UNIQUE
-- constraint on ADDRESS, which must therefore exist before that FK is
-- created. Both PK and UNIQUE constraints can be FK targets, so both must
-- come first.
--
-- Every constraint is explicitly named using:
--   PK_<TABLE>
--   FK_<TABLE>_<REFERENCED_TABLE>
--   UK_<TABLE>_<COLUMN>
--   CK_<TABLE>_<RULE>
--
-- Deliberate non-constraints (documented, not silently omitted):
--   - RESTAURANT.PHONE / RESTAURANT.EMAIL are NOT unique. A restaurant
--     chain can legitimately route several outlets through one shared
--     support line or contact email (relevant once "Restaurant Branch"
--     is introduced later in this project's roadmap).
--   - RESTAURANT.PHONE has no exact-length CHECK, unlike CUSTOMER and
--     DELIVERY_PERSON, whose personal-mobile-number assumption doesn't
--     apply to a restaurant's (possibly landline) contact number.
--
-- ON DELETE behavior: every FK below intentionally uses Oracle's default,
-- NO ACTION. CUSTOMER, ORDERS, PAYMENT and REVIEW are historical business
-- records — deleting a customer should never silently cascade-delete
-- their order/payment/review history. Deliberate, not an oversight.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- PRIMARY KEYS
--------------------------------------------------------------------------------

ALTER TABLE RESTAURANT
    ADD CONSTRAINT PK_RESTAURANT PRIMARY KEY (RESTAURANT_ID);

ALTER TABLE CATEGORY
    ADD CONSTRAINT PK_CATEGORY PRIMARY KEY (CATEGORY_ID);

-- Composite PK: a restaurant can have many categories, but not the exact
-- same (restaurant, category) pairing twice.
ALTER TABLE RESTAURANT_CATEGORY
    ADD CONSTRAINT PK_RESTAURANT_CATEGORY PRIMARY KEY (RESTAURANT_ID, CATEGORY_ID);

ALTER TABLE MENU
    ADD CONSTRAINT PK_MENU PRIMARY KEY (MENU_ID);

ALTER TABLE MENU_ITEM
    ADD CONSTRAINT PK_MENU_ITEM PRIMARY KEY (ITEM_ID);

ALTER TABLE CUSTOMER
    ADD CONSTRAINT PK_CUSTOMER PRIMARY KEY (CUSTOMER_ID);

ALTER TABLE ADDRESS
    ADD CONSTRAINT PK_ADDRESS PRIMARY KEY (ADDRESS_ID);

ALTER TABLE DELIVERY_PERSON
    ADD CONSTRAINT PK_DELIVERY_PERSON PRIMARY KEY (DELIVERY_ID);

ALTER TABLE ORDERS
    ADD CONSTRAINT PK_ORDERS PRIMARY KEY (ORDER_ID);

-- Renamed from the original COMPOSIT_PK_ORDER_ITEM_ID (typo: "COMPOSIT").
-- One row per (order, item) pair.
ALTER TABLE ORDER_ITEM
    ADD CONSTRAINT PK_ORDER_ITEM PRIMARY KEY (ORDER_ID, ITEM_ID);

ALTER TABLE PAYMENT
    ADD CONSTRAINT PK_PAYMENT PRIMARY KEY (PAYMENT_ID);

ALTER TABLE REVIEW
    ADD CONSTRAINT PK_REVIEW PRIMARY KEY (REVIEW_ID);

--------------------------------------------------------------------------------
-- UNIQUE CONSTRAINTS
--------------------------------------------------------------------------------

ALTER TABLE CUSTOMER
    ADD CONSTRAINT UK_CUSTOMER_PHONE UNIQUE (PHONE);

ALTER TABLE CUSTOMER
    ADD CONSTRAINT UK_CUSTOMER_EMAIL UNIQUE (EMAIL);

ALTER TABLE CATEGORY
    ADD CONSTRAINT UK_CATEGORY_NAME UNIQUE (CATEGORY_NAME);

ALTER TABLE DELIVERY_PERSON
    ADD CONSTRAINT UK_DELIVERY_PERSON_PHONE UNIQUE (PHONE);

ALTER TABLE DELIVERY_PERSON
    ADD CONSTRAINT UK_DELIVERY_PERSON_VEHICLE_NO UNIQUE (VEHICLE_NO);

-- This is what actually enforces the documented ORDERS -> PAYMENT 1-to-1
-- relationship. A UNIQUE constraint on the FK column means each ORDER_ID
-- can appear in PAYMENT at most once; combined with the FK (every
-- PAYMENT.ORDER_ID must point to a real order), that is "1-to-1" at the
-- data level. No separate table is needed.
ALTER TABLE PAYMENT
    ADD CONSTRAINT UK_PAYMENT_ORDER UNIQUE (ORDER_ID);

-- PHASE 4: lets ADDRESS be the target of a composite FK from ORDERS. This
-- costs nothing beyond what already holds — ADDRESS_ID is already globally
-- unique via PK_ADDRESS, so (ADDRESS_ID, CUSTOMER_ID) is automatically
-- unique too. Its purpose is purely to be a valid FK target for the
-- composite FK below.
ALTER TABLE ADDRESS
    ADD CONSTRAINT UK_ADDRESS_ID_CUSTOMER_ID UNIQUE (ADDRESS_ID, CUSTOMER_ID);

-- PHASE 4: one review per order (see docs/normalization.md, Deep Dive 3).
ALTER TABLE REVIEW
    ADD CONSTRAINT UK_REVIEW_ORDER UNIQUE (ORDER_ID);

--------------------------------------------------------------------------------
-- FOREIGN KEYS
--------------------------------------------------------------------------------

-- Fixes: RESTAURANT_CATEGORY previously had no FKs at all (Phase 2, #4).
ALTER TABLE RESTAURANT_CATEGORY
    ADD CONSTRAINT FK_RESTAURANT_CATEGORY_RESTAURANT
        FOREIGN KEY (RESTAURANT_ID) REFERENCES RESTAURANT (RESTAURANT_ID);

ALTER TABLE RESTAURANT_CATEGORY
    ADD CONSTRAINT FK_RESTAURANT_CATEGORY_CATEGORY
        FOREIGN KEY (CATEGORY_ID) REFERENCES CATEGORY (CATEGORY_ID);

-- Fixes: MENU previously had no FK back to RESTAURANT (Phase 1/2, #2/#3).
ALTER TABLE MENU
    ADD CONSTRAINT FK_MENU_RESTAURANT
        FOREIGN KEY (RESTAURANT_ID) REFERENCES RESTAURANT (RESTAURANT_ID);

ALTER TABLE MENU_ITEM
    ADD CONSTRAINT FK_MENU_ITEM_MENU
        FOREIGN KEY (MENU_ID) REFERENCES MENU (MENU_ID);

ALTER TABLE ADDRESS
    ADD CONSTRAINT FK_ADDRESS_CUSTOMER
        FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMER (CUSTOMER_ID);

ALTER TABLE ORDERS
    ADD CONSTRAINT FK_ORDERS_CUSTOMER
        FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMER (CUSTOMER_ID);

ALTER TABLE ORDERS
    ADD CONSTRAINT FK_ORDERS_RESTAURANT
        FOREIGN KEY (RESTAURANT_ID) REFERENCES RESTAURANT (RESTAURANT_ID);

-- PHASE 4: composite FK, not a plain single-column FK. This guarantees
-- the address an order ships to actually belongs to the customer who
-- placed that order — a bare FK to ADDRESS.ADDRESS_ID alone would let an
-- order reference any customer's address in the system. See
-- docs/normalization.md, Deep Dive 2. Column order (ADDRESS_ID,
-- CUSTOMER_ID) must match UK_ADDRESS_ID_CUSTOMER_ID's column order above.
ALTER TABLE ORDERS
    ADD CONSTRAINT FK_ORDERS_ADDRESS
        FOREIGN KEY (ADDRESS_ID, CUSTOMER_ID) REFERENCES ADDRESS (ADDRESS_ID, CUSTOMER_ID);

-- Fixes: ORDERS.DELIVERY_ID previously had no FK (Phase 1/2, #5).
-- DELIVERY_ID stays nullable at the column level (see 01_tables.sql) —
-- a freshly PLACED order legitimately has no delivery person yet.
ALTER TABLE ORDERS
    ADD CONSTRAINT FK_ORDERS_DELIVERY_PERSON
        FOREIGN KEY (DELIVERY_ID) REFERENCES DELIVERY_PERSON (DELIVERY_ID);

ALTER TABLE ORDER_ITEM
    ADD CONSTRAINT FK_ORDER_ITEM_ORDERS
        FOREIGN KEY (ORDER_ID) REFERENCES ORDERS (ORDER_ID);

ALTER TABLE ORDER_ITEM
    ADD CONSTRAINT FK_ORDER_ITEM_MENU_ITEM
        FOREIGN KEY (ITEM_ID) REFERENCES MENU_ITEM (ITEM_ID);

ALTER TABLE PAYMENT
    ADD CONSTRAINT FK_PAYMENT_ORDERS
        FOREIGN KEY (ORDER_ID) REFERENCES ORDERS (ORDER_ID);

-- PHASE 4: replaces the removed FK_REVIEW_CUSTOMER / FK_REVIEW_RESTAURANT.
-- A review now points at the specific order it rates; CUSTOMER_ID and
-- RESTAURANT_ID are reached via a join through ORDERS instead of being
-- stored redundantly. See docs/normalization.md, Deep Dive 3.
ALTER TABLE REVIEW
    ADD CONSTRAINT FK_REVIEW_ORDERS
        FOREIGN KEY (ORDER_ID) REFERENCES ORDERS (ORDER_ID);

--------------------------------------------------------------------------------
-- CHECK CONSTRAINTS
--------------------------------------------------------------------------------

-- Phone length checks assume domestic 10-digit mobile numbers with no
-- country code stored — the actual format currently used throughout the
-- project's seed data. Supporting international "+<code>" formats would
-- be a future, explicit business-rule change, not something to infer here.
ALTER TABLE CUSTOMER
    ADD CONSTRAINT CK_CUSTOMER_PHONE_LEN CHECK (LENGTH(PHONE) = 10);

ALTER TABLE CUSTOMER
    ADD CONSTRAINT CK_CUSTOMER_GENDER CHECK (GENDER IN ('M', 'F', 'O'));

ALTER TABLE DELIVERY_PERSON
    ADD CONSTRAINT CK_DELIVERY_PERSON_PHONE_LEN CHECK (LENGTH(PHONE) = 10);

ALTER TABLE DELIVERY_PERSON
    ADD CONSTRAINT CK_DELIVERY_PERSON_STATUS CHECK (STATUS IN ('AVAILABLE', 'BUSY'));

ALTER TABLE ADDRESS
    ADD CONSTRAINT CK_ADDRESS_TYPE CHECK (ADDRESS_TYPE IN ('HOME', 'OFFICE', 'OTHER'));

-- Guards the exact leading-zero data-loss bug identified in Phase 2:
-- must be exactly 6 digits, numeric only.
ALTER TABLE ADDRESS
    ADD CONSTRAINT CK_ADDRESS_PINCODE_FORMAT CHECK (REGEXP_LIKE(PINCODE, '^[0-9]{6}$'));

ALTER TABLE MENU_ITEM
    ADD CONSTRAINT CK_MENU_ITEM_PRICE CHECK (PRICE > 0);

ALTER TABLE MENU_ITEM
    ADD CONSTRAINT CK_MENU_ITEM_AVAILABLE_STATUS CHECK (AVAILABLE_STATUS IN ('YES', 'NO'));

ALTER TABLE ORDERS
    ADD CONSTRAINT CK_ORDERS_TOTAL_AMOUNT CHECK (TOTAL_AMOUNT >= 0);

ALTER TABLE ORDERS
    ADD CONSTRAINT CK_ORDERS_STATUS
        CHECK (ORDER_STATUS IN ('PLACED', 'ONWAY', 'DELIVERED', 'CANCELLED'));

ALTER TABLE ORDER_ITEM
    ADD CONSTRAINT CK_ORDER_ITEM_QUANTITY CHECK (QUANTITY > 0);

ALTER TABLE ORDER_ITEM
    ADD CONSTRAINT CK_ORDER_ITEM_PRICE CHECK (PRICE > 0);

ALTER TABLE PAYMENT
    ADD CONSTRAINT CK_PAYMENT_MODE CHECK (PAYMENT_MODE IN ('CARD', 'CASH', 'UPI'));

ALTER TABLE PAYMENT
    ADD CONSTRAINT CK_PAYMENT_AMOUNT CHECK (AMOUNT > 0);

ALTER TABLE PAYMENT
    ADD CONSTRAINT CK_PAYMENT_STATUS CHECK (PAYMENT_STATUS IN ('SUCCESS', 'FAILED', 'PENDING'));

ALTER TABLE REVIEW
    ADD CONSTRAINT CK_REVIEW_RATING CHECK (RATING BETWEEN 1 AND 5);

-- Phase 3 TYPE/range fix only. Whether RESTAURANT.RATING should exist at
-- all (it may be an independently-sourced or cached aggregate value) was
-- explicitly evaluated in Phase 4 (docs/normalization.md, Deep Dive 4)
-- and retained, not removed.
ALTER TABLE RESTAURANT
    ADD CONSTRAINT CK_RESTAURANT_RATING CHECK (RATING BETWEEN 1 AND 5);

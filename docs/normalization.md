# Phase 4 — Normalization & Relational Design

This document records the 1NF/2NF/3NF analysis performed on the schema as it
stood after Phase 3 (`database/schema/01_tables.sql` +
`database/schema/02_constraints.sql`), the anomalies and design questions it
surfaced, and the reasoning behind every change (or deliberate non-change)
made as a result.

## 1. Table-by-table analysis

| Table | PK | Candidate Keys | 1NF | 2NF | 3NF | Decision |
|---|---|---|---|---|---|---|
| RESTAURANT | RESTAURANT_ID | {RESTAURANT_ID} | Yes | Yes | See §4 | Retain, documented |
| CATEGORY | CATEGORY_ID | {CATEGORY_ID}, {CATEGORY_NAME} | Yes | Yes | Yes | Good as-is |
| RESTAURANT_CATEGORY | (RESTAURANT_ID, CATEGORY_ID) | composite PK only | Yes | Yes (trivial, no non-key attrs) | Yes | Good as-is |
| MENU | MENU_ID | {MENU_ID} | Yes | Yes | Yes | Good as-is |
| MENU_ITEM | ITEM_ID | {ITEM_ID} | Yes | Yes | Yes | Good as-is |
| CUSTOMER | CUSTOMER_ID | {CUSTOMER_ID}, {PHONE}, {EMAIL} | Yes | Yes | Yes | Good as-is |
| ADDRESS | ADDRESS_ID | {ADDRESS_ID} | Yes | Yes | Yes | Good as-is (structurally) |
| DELIVERY_PERSON | DELIVERY_ID | {DELIVERY_ID}, {PHONE} | Yes | Yes | Yes | Good as-is |
| ORDERS | ORDER_ID | {ORDER_ID} | Yes | Yes | See §3 | **Changed** (added ADDRESS_ID) |
| ORDER_ITEM | (ORDER_ID, ITEM_ID) | composite PK only | Yes | Yes — see §2 | Yes | Good as-is |
| PAYMENT | PAYMENT_ID | {PAYMENT_ID}, {ORDER_ID} | Yes | Yes | Yes | Good as-is |
| REVIEW | REVIEW_ID | {REVIEW_ID} | Yes | Yes | **No** (pre-change) | **Changed** (ORDER_ID replaces CUSTOMER_ID/RESTAURANT_ID) |

### Notable functional dependencies
- `ORDER_ITEM`: `(ORDER_ID, ITEM_ID) → PRICE` — genuinely a full-key dependency (§2), not a partial one.
- `RESTAURANT`: `RESTAURANT_ID → RATING` — satisfied, but `RATING` is not intrinsic restaurant data (§4).
- `ORDERS`: `ORDER_ID → TOTAL_AMOUNT` — same pattern as `RATING`: a cached aggregate of `SUM(ORDER_ITEM.QUANTITY × PRICE)`, retained unchanged, not resolved in this phase.
- `REVIEW` (pre-Phase-4): `REVIEW_ID → CUSTOMER_ID, RESTAURANT_ID`, but also (if `ORDER_ID` were merely added alongside them) `REVIEW_ID → ORDER_ID → CUSTOMER_ID/RESTAURANT_ID` — a transitive dependency, hence a real 3NF violation (§3).

## 2. Deep dive — ORDER_ITEM.PRICE (kept, not removed)

The intuitive objection is "`PRICE` depends on `ITEM_ID` alone, so it belongs
only in `MENU_ITEM`." That's the wrong functional dependency. `ORDER_ITEM.PRICE`
represents *the price of this item at the moment this specific order was
placed* — a fact about the `(ORDER_ID, ITEM_ID)` pair, not about `ITEM_ID` in
isolation. The same `ITEM_ID` can correctly show different `ORDER_ITEM.PRICE`
values across different historical orders if the restaurant repriced the item
in between. The true dependency, `(ORDER_ID, ITEM_ID) → PRICE-at-order-time`,
requires the full composite key, so this is **not** a 2NF violation.

Removing this column and deriving price via a join to `MENU_ITEM` at query
time would silently rewrite historical order totals whenever a restaurant
changes a price — a real correctness/audit bug. **Decision: retained,
intentional historical snapshot.**

## 3. Deep dive — REVIEW → ORDER_ID (changed)

**Before:** `REVIEW(REVIEW_ID, CUSTOMER_ID, RESTAURANT_ID, RATING, COMMENTS, REVIEW_DATE)`
**After:** `REVIEW(REVIEW_ID, ORDER_ID, RATING, COMMENTS, REVIEW_DATE)`

Reasoning, question by question:
- **Should only customers who ordered be able to review?** Yes — matches how verified-purchase review systems actually work, and nothing enforced this before.
- **Should one review belong to one order?** Yes — this is more realistic than one review per customer-restaurant pair for life, since it allows "great last time, disappointing this time" across repeat orders.
- **Do CUSTOMER_ID/RESTAURANT_ID become redundant?** Yes. `ORDERS` already stores both, so keeping all three in `REVIEW` creates `REVIEW_ID → ORDER_ID → CUSTOMER_ID/RESTAURANT_ID`: a transitive dependency, and therefore a genuine 3NF violation, with a real anomaly risk (nothing would guarantee `REVIEW.CUSTOMER_ID` actually matched `ORDERS.CUSTOMER_ID` for that order).
- **Candidate key implications:** `UNIQUE(ORDER_ID)` now precisely enforces "one review per order," which a `(CUSTOMER_ID, RESTAURANT_ID)` uniqueness rule could not do without also blocking legitimate repeat-order reviews.

`CUSTOMER_ID`/`RESTAURANT_ID` remain fully accessible via a join through `ORDERS`.

**Stated assumption:** this reframes a "review" from *"a customer's opinion of
a restaurant in general"* to *"a customer's rating of one specific order."*
This is a business-model interpretation, not a purely mechanical fix — flagged
explicitly rather than made silently.

## 4. Deep dive — RESTAURANT.RATING (retained, not removed)

Before deciding, the actual seed data was checked: `RESTAURANT` row 1 has
`RATING = 4.5`, while the one `REVIEW` row for restaurant 1 has `RATING = 5`.
**They don't match.** Empirically, `RESTAURANT.RATING` in this dataset is not
simply a live cache of `AVG(REVIEW.RATING)` — it behaves more like an
independently-sourced "overall/official rating," the kind of blended signal
real platforms display separately from raw in-app review scores. Removing it
now would destroy real data, not redundant data.

Trade-off considered: computing it live via `AVG()` avoids staleness but adds
a join+aggregate to a read-heavy path (restaurant listings); storing it avoids
that cost but risks drifting from `REVIEW` over time. **Decision: retained
as-is**, documented as a possibly-independent or intentionally denormalized
value. Whether to auto-refresh it (a trigger, or replacing it with a Phase 7
view) is explicitly deferred, not decided here.

## 5. Deep dive — ORDERS → ADDRESS (changed)

**Before:** `ORDERS` had no reference to a delivery address at all — a real
missing relationship, not a cosmetic gap, given `CUSTOMER` can have multiple
`ADDRESS` rows (HOME/OFFICE/OTHER).

**Options compared:**
1. Plain FK `ORDERS.ADDRESS_ID → ADDRESS.ADDRESS_ID`.
2. Snapshot the full address text into `ORDERS` as its own columns (same pattern as `ORDER_ITEM.PRICE`).
3. Hybrid (FK + snapshot).

**Chosen: option 1, strengthened to a composite FK.** The snapshot pattern
(option 2/3) is justified for `ORDER_ITEM.PRICE` because `MENU_ITEM` prices
genuinely change over time and `ORDER_ITEM` needs to survive that. `ADDRESS`
rows in this schema are never updated — there is no editing/versioning
workflow for addresses at all. Building a snapshot to guard against a
mutation path that doesn't exist yet would be solving a hypothetical problem,
not a real one; it can be revisited if address editing is ever added.

A plain single-column FK, however, has a real gap: it would let an order
reference *any* address in the system, including one belonging to a different
customer. This is closed declaratively — no trigger — by:
- Adding `UNIQUE(ADDRESS_ID, CUSTOMER_ID)` on `ADDRESS` (free: `ADDRESS_ID` is already globally unique via its PK).
- Making `ORDERS` carry a **composite FK**: `(ADDRESS_ID, CUSTOMER_ID) → ADDRESS(ADDRESS_ID, CUSTOMER_ID)`.

This guarantees an order's delivery address always belongs to that order's
own customer, enforced purely by constraints. `ORDERS.ADDRESS_ID` is `NOT
NULL` — an order that can't be delivered anywhere isn't a valid state.

## 6. Anomalies this phase fixes

| Anomaly type | Before | After |
|---|---|---|
| Missing relationship (insert/business-rule gap) | An order could be placed with no record of where it ships | `ORDERS.ADDRESS_ID` required, and must belong to the ordering customer |
| Missing relationship | A review could exist for a restaurant the customer never ordered from | `REVIEW.ORDER_ID` FK makes this impossible |
| Update anomaly (structural risk) | If `ORDER_ID` had been added to `REVIEW` alongside `CUSTOMER_ID`/`RESTAURANT_ID`, editing an order's customer could leave `REVIEW`'s copies stale | Avoided by not introducing the redundant columns in the first place |
| Insert anomaly | Nothing stopped multiple reviews for the same customer-restaurant pair, or unlimited reviews with no purchase | `UNIQUE(ORDER_ID)` + FK to `ORDERS` closes both |

## 7. Intentional denormalization retained (not "fixed")

- **`ORDER_ITEM.PRICE`** — order-time price snapshot (§2).
- **`RESTAURANT.RATING`** — likely independently-sourced or cached aggregate rating (§4).
- **`ORDERS.TOTAL_AMOUNT`** — cached aggregate of order-line totals, same performance rationale as `RATING`; not resolved in this phase.

None of these were removed. Each is documented at its column definition in
`01_tables.sql` so a future reader doesn't mistake it for an oversight.

## 8. Before / after model summary

```
Before (post-Phase-3):
  ORDERS(ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, DELIVERY_ID,
         ORDER_DATE, TOTAL_AMOUNT, ORDER_STATUS)
  REVIEW(REVIEW_ID, CUSTOMER_ID, RESTAURANT_ID, RATING, COMMENTS, REVIEW_DATE)

After (Phase 4):
  ORDERS(ORDER_ID, CUSTOMER_ID, RESTAURANT_ID, ADDRESS_ID, DELIVERY_ID,
         ORDER_DATE, TOTAL_AMOUNT, ORDER_STATUS)
    + composite FK (ADDRESS_ID, CUSTOMER_ID) -> ADDRESS(ADDRESS_ID, CUSTOMER_ID)

  REVIEW(REVIEW_ID, ORDER_ID, RATING, COMMENTS, REVIEW_DATE)
    + FK ORDER_ID -> ORDERS(ORDER_ID), UNIQUE(ORDER_ID)
```

All 10 other tables are unchanged from Phase 3.

## 9. Trade-offs accepted

- `REVIEW` now requires a join through `ORDERS` to reach `CUSTOMER_ID`/`RESTAURANT_ID` — a small query-complexity cost in exchange for removing a real transitive dependency. This is a good candidate for a `VW_REVIEW_DETAILS` view in a later phase.
- The `ORDERS`/`ADDRESS` composite FK requires both columns to be supplied together on every insert — slightly more ceremony than a single-column FK, in exchange for a correctness guarantee (address must belong to the ordering customer) that a trigger would otherwise have been needed to enforce.
- `RESTAURANT.RATING` and `ORDERS.TOTAL_AMOUNT` remain potential sources of drift from their underlying detail tables. This is accepted for now as a read-performance trade-off, not solved.

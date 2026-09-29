# Phase 6 — Query Analysis & Performance Awareness

This document identifies which queries in `database/queries/*.sql` are
heavier than others and which columns would be the first candidates for
indexing — **no indexes are created in this phase**. That's deliberately
deferred so indexing decisions can be made from evidence (`EXPLAIN PLAN` /
`DBMS_XPLAN`) in a later phase, not guessed at now.

## 1. Query categories in this project

| File | Focus | Approx. query count |
|---|---|---:|
| `basic_queries.sql` | Filtering, sorting, single-relationship joins | 17 |
| `advanced_queries.sql` | Multi-table joins, aggregation, subqueries, CTEs, window functions, Top-N | ~65 |
| `analytics.sql` | Business-domain reporting (restaurant/customer/menu/delivery/order/payment/review) + historical price analysis | ~35 |

## 2. Important joins

The join backbone used throughout is:
```
CUSTOMER -> ORDERS -> RESTAURANT
ORDERS -> ORDER_ITEM -> MENU_ITEM -> MENU
ORDERS -> PAYMENT
ORDERS -> REVIEW   (via ORDER_ID, since Phase 4 removed REVIEW.CUSTOMER_ID/RESTAURANT_ID)
ORDERS -> ADDRESS  (via the Phase 4 composite FK)
```
`ORDERS` is the busiest join target in the schema — it sits at the center of
almost every analytical query (revenue, spending, delivery workload, reviews
all route through it).

## 3. Aggregation-heavy queries

Anything grouping by `RESTAURANT_ID` or `CUSTOMER_ID` over `ORDERS` (revenue,
spend, order counts — Sections B, C, and most of `analytics.sql`) scans the
full 2,000-row `ORDERS` table today. At 2,000 rows this is trivial; the
concern is what happens at real production scale (millions of orders), not
at this dataset's size.

## 4. Subquery-heavy queries

The correlated subqueries in Section E/N (`E5`/`N4`: items priced above
their own restaurant's average; `E7`: orders above their own restaurant's
average order value) re-evaluate their inner query **once per outer row**,
grouped implicitly by `RESTAURANT_ID`. This is the right SQL for the
question being asked, but it's inherently more expensive than a flat,
non-correlated comparison (like `E4`) because the "average" isn't computed
once — it's computed per group.

## 5. Window-function queries

Section J/K/L/M (`RANK`, `ROW_NUMBER`, `LAG`/`LEAD`, running totals) require
sorting the relevant data (often within a `PARTITION BY RESTAURANT_ID` or
`PARTITION BY CUSTOMER_ID`). These reread the same `ORDERS`/`ORDER_ITEM` data
that the aggregation queries do, just with an added sort step per partition.

## 6. Potentially expensive queries (worth watching, not fixing)

- **K1/K4/J6** (Top-N menu items per restaurant, by quantity/revenue): joins `MENU_ITEM -> MENU -> ORDER_ITEM` and aggregates before ranking — three tables touched for every one of ~400 menu items.
- **E5/N4** (menu items above their own restaurant's average price): a correlated subquery re-scanning `MENU_ITEM` joined to `MENU` for every one of ~400 rows.
- **M3/M4** (running totals partitioned by customer/restaurant): requires an ordered scan per partition; correct and readable, but not the same cost profile as a simple aggregate.
- **Historical Price Analysis queries** (all of them): every one joins `ORDER_ITEM` to `MENU_ITEM` across all 5,370 order-item rows with an inequality filter (`oi.PRICE <> mi.PRICE`) — currently cheap, but this is the query shape most likely to be run often (e.g. a "price change report") and worth watching as data grows.

## 7. Likely future index candidates

Listed here as **observations for a later phase**, not implemented now:

| Column(s) | Why it would help | Which queries |
|---|---|---|
| `ORDERS.RESTAURANT_ID` | Every restaurant-grouped aggregation filters/joins on this | Sections B, C, D, most of `analytics.sql` |
| `ORDERS.CUSTOMER_ID` | Every customer-grouped aggregation filters/joins on this | Sections B, C, D, L, M3 |
| `ORDERS.ORDER_DATE` | Every date-range filter and `TRUNC(ORDER_DATE,'MM')` grouping | Section I, H5, M1/M2 |
| `ORDER_ITEM.ITEM_ID` | Menu-item-level aggregation (best-sellers, revenue-per-item, Top-N) | Sections J4, K1, K4, Menu Analytics |
| `REVIEW.ORDER_ID` | Already has `UK_REVIEW_ORDER` (a unique index exists implicitly) — no action needed | Review Analytics |
| `PAYMENT.ORDER_ID` | Already has `UK_PAYMENT_ORDER` — no action needed | Payment Analytics |

## 8. Why indexing should be evaluated later, not added now

1. **No evidence yet.** Nothing in this phase has run against a real Oracle
   instance with `EXPLAIN PLAN`/`DBMS_XPLAN` — adding indexes based on
   guesses about "which columns look busy" is exactly the kind of premature
   optimization this project's own rules (`Do not invent performance
   improvements`) warn against.
2. **2,000 orders is not a scale where indexing matters.** A full table scan
   over 2,000 rows is fast regardless of indexing; the value of an index
   only becomes visible (and measurable) at a much larger row count or with
   real concurrent query load.
3. **Indexes have a cost, not just a benefit.** Every index added slows down
   `INSERT`/`UPDATE` on that table and takes storage — that trade-off should
   be justified by an actual slow query, not applied speculatively to
   columns that merely "look important."
4. **This phase is query-only by design.** Mixing schema/performance changes
   into a phase meant to prove out the query layer would make it harder to
   tell whether a later regression came from the queries or from an index
   change made at the same time.

The table in §7 is the starting point for that future, evidence-driven
indexing phase — not a to-do list to implement immediately.

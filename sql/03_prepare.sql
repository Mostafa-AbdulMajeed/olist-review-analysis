-- ============================================================
-- Olist analysis — Stage 3: Clean & Prepare
-- Goal: make the analysis-ready views. Every decision here is
-- justified against the business question ("what drives bad
-- reviews?"), not made for its own sake — that's the analyst
-- discipline vs. the engineer instinct to normalize everything.
-- ============================================================

-- Decision 1: one review per order.
-- A handful of orders have 2+ review rows (customer resubmitted an
-- answer). Keep the most recent one — it reflects the customer's
-- final opinion, which is what we care about.
CREATE OR REPLACE VIEW reviews_dedup AS
SELECT DISTINCT ON (order_id)
    order_id, review_score, review_creation_date, review_answer_timestamp
FROM order_reviews
ORDER BY order_id, review_answer_timestamp DESC;

-- Decision 2: order-level revenue, not item-level.
-- order_items fans out (1 order -> many item rows). Aggregate to
-- order grain FIRST so joins downstream don't silently multiply
-- revenue or count an order more than once.
CREATE OR REPLACE VIEW order_revenue AS
SELECT
    order_id,
    SUM(price)                 AS total_price,
    SUM(freight_value)         AS total_freight,
    SUM(price + freight_value) AS total_order_value,
    COUNT(*)                   AS item_count
FROM order_items
GROUP BY order_id;

-- Decision 3: scope to delivered orders, cut sparse 2016 data,
-- and compute delay decomposed into its 3 handoff stages.
-- delay_days > 0 means delivered later than promised.
CREATE OR REPLACE VIEW orders_clean AS
SELECT
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    EXTRACT(EPOCH FROM (order_delivered_customer_date - order_estimated_delivery_date)) / 86400.0 AS delay_days,
    EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp)) / 86400.0            AS approval_days,
    EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 86400.0         AS seller_handling_days,
    EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 86400.0 AS carrier_transit_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01';   -- 2016 is too sparse to trend on; check Stage 2 output #2 first

-- Decision 4: the single analysis-ready table everything else queries.
-- Grain: one row per delivered, reviewed order.
CREATE OR REPLACE VIEW analysis_base AS
SELECT
    oc.order_id,
    oc.order_purchase_timestamp,
    date_trunc('month', oc.order_purchase_timestamp) AS order_month,
    oc.delay_days,
    oc.approval_days,
    oc.seller_handling_days,
    oc.carrier_transit_days,
    (oc.delay_days > 0)      AS was_late,
    r.review_score,
    (r.review_score <= 2)    AS is_bad_review,
    c.customer_state,
    c.customer_city,
    rev.total_order_value,
    rev.item_count
FROM orders_clean oc
JOIN reviews_dedup r  ON oc.order_id = r.order_id
JOIN customers c      ON oc.customer_id = c.customer_id
JOIN order_revenue rev ON oc.order_id = rev.order_id;

-- Sanity check: row count should be close to (but a bit under) the
-- delivered-order count from Stage 2 #3 — some delivered orders
-- never got reviewed, which is expected (see Stage 2 #5).
SELECT COUNT(*) FROM analysis_base;

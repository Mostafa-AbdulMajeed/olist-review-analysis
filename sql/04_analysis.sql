-- ============================================================
-- Olist analysis — Stage 4: Answer the question
-- Business question: What drives bad reviews at Olist, and what
-- should we do about it?
-- Layered: overall -> segment -> drill -> root cause.
-- ============================================================

-- 1. OVERALL — how big is the problem?
SELECT
    ROUND(100.0 * AVG(CASE WHEN is_bad_review THEN 1 ELSE 0 END), 1) AS pct_bad_reviews,
    ROUND(100.0 * AVG(CASE WHEN was_late THEN 1 ELSE 0 END), 1)      AS pct_late_orders,
    ROUND(AVG(review_score), 2)                                       AS avg_review_score,
    COUNT(*)                                                          AS n_orders
FROM analysis_base;

-- 2. HEADLINE — does lateness actually move review scores?
SELECT
    was_late,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(100.0 * AVG(CASE WHEN is_bad_review THEN 1 ELSE 0 END), 1) AS pct_bad_reviews,
    COUNT(*) AS n_orders
FROM analysis_base
GROUP BY was_late
ORDER BY was_late;

-- 3. GRANULAR — does severity of lateness matter, or is any lateness equally bad?
SELECT
    CASE
        WHEN delay_days <= 0 THEN 'on_time'
        WHEN delay_days <= 3 THEN 'late_1_3_days'
        WHEN delay_days <= 7 THEN 'late_4_7_days'
        ELSE 'late_8plus_days'
    END AS delay_bucket,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(*) AS n_orders
FROM analysis_base
GROUP BY delay_bucket
ORDER BY MIN(delay_days);

-- 4. ROOT CAUSE — which handoff stage drives the delay: seller
-- shipping slowly, or carrier transit being slow?
-- (This decomposition is the insight that turns "we're late" into
-- "we're late at a specific, fixable handoff.")
SELECT
    was_late,
    ROUND(AVG(seller_handling_days), 2) AS avg_seller_handling_days,
    ROUND(AVG(carrier_transit_days), 2) AS avg_carrier_transit_days,
    COUNT(*) AS n_orders
FROM analysis_base
WHERE seller_handling_days IS NOT NULL AND carrier_transit_days IS NOT NULL
GROUP BY was_late;

-- 5. SEGMENT — worst states by late rate and review score
-- (minimum volume filter so a state with 5 orders doesn't top the list)
SELECT
    customer_state,
    COUNT(*) AS n_orders,
    ROUND(100.0 * AVG(CASE WHEN was_late THEN 1 ELSE 0 END), 1) AS pct_late,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM analysis_base
GROUP BY customer_state
HAVING COUNT(*) >= 100          -- minimum volume filter — drop noisy small states
ORDER BY pct_late DESC
LIMIT 10;

-- 6. TREND — is this getting better or worse over time?
SELECT
    order_month,
    ROUND(100.0 * AVG(CASE WHEN was_late THEN 1 ELSE 0 END), 1) AS pct_late,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(*) AS n_orders
FROM analysis_base
GROUP BY order_month
ORDER BY order_month;

-- 7. CATEGORY drill-down — separate query because category lives at
-- item grain, not order grain (one order can span multiple categories,
-- so this is NOT joined off analysis_base — avoid re-introducing the
-- item-level fanout into an order-level table).
SELECT
    ct.product_category_name_english AS category,
    COUNT(*) AS n_items,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_items oi
JOIN products p            ON oi.product_id = p.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
JOIN reviews_dedup r        ON oi.order_id = r.order_id
GROUP BY category
HAVING COUNT(*) >= 100           -- minimum volume filter
ORDER BY avg_review_score ASC
LIMIT 15;

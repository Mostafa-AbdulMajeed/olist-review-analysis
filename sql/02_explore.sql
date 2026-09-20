-- ============================================================
-- Olist analysis — Stage 2: Explore
-- Goal: understand the data's shape before asking any real question.
-- Not fixing anything here — just looking. Write down what's odd,
-- decide what to do about it in Stage 3.
-- ============================================================

-- 1. Row-level sanity: confirm order_items fans out (1 order -> many item rows)
SELECT order_id, COUNT(*) AS item_count
FROM order_items
GROUP BY order_id
ORDER BY item_count DESC
LIMIT 10;

-- 2. Date range and monthly volume — find where the data thins out
SELECT date_trunc('month', order_purchase_timestamp) AS month, COUNT(*)
FROM orders
GROUP BY month
ORDER BY month;

-- 3. Order status breakdown — decide what "delivered" means for this analysis
SELECT order_status, COUNT(*)
FROM orders
GROUP BY order_status
ORDER BY COUNT(*) DESC;

-- 4. Null patterns on delivery dates — a null isn't a defect, it's a story
SELECT
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS never_delivered,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS never_approved,
    COUNT(*) AS total
FROM orders;

-- 5. Review coverage — is review data biased toward people who bother to respond?
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT r.order_id) AS orders_with_review
FROM orders o
LEFT JOIN order_reviews r ON o.order_id = r.order_id;

-- 6. Review score distribution — the shape of the target variable
SELECT review_score, COUNT(*)
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 7. Duplicate reviews per order — second fanout risk, same category as #1
SELECT review_count, COUNT(*) AS num_orders
FROM (
    SELECT order_id, COUNT(*) AS review_count
    FROM order_reviews
    GROUP BY order_id
) sub
GROUP BY review_count
ORDER BY review_count;

-- ============================================================
-- Olist analysis — Stage 5: Dashboard feed
-- One flat view for Power BI to connect to directly. Order grain,
-- includes a "primary_category" per order (the category of its
-- highest-value item) so category can be sliced without
-- reintroducing item-level fanout into the review/delay metrics.
-- ============================================================

CREATE OR REPLACE VIEW vw_powerbi_export AS
WITH primary_category AS (
    SELECT DISTINCT ON (oi.order_id)
        oi.order_id,
        ct.product_category_name_english AS primary_category
    FROM order_items oi
    JOIN products p             ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    ORDER BY oi.order_id, oi.price DESC
)
SELECT
    ab.order_id,
    ab.order_purchase_timestamp,
    ab.order_month,
    ab.delay_days,
    ab.was_late,
    ab.review_score,
    ab.is_bad_review,
    ab.customer_state,
    ab.customer_city,
    ab.total_order_value,
    ab.item_count,
    pc.primary_category
FROM analysis_base ab
LEFT JOIN primary_category pc ON ab.order_id = pc.order_id;

-- Point Power BI's Postgres connector at this view (or at
-- "SELECT * FROM vw_powerbi_export" as a custom query) and build:
--   - avg review_score and pct_late as KPI cards
--   - review_score trend by order_month (line)
--   - pct_late by customer_state (map or bar, filter n>=100)
--   - avg review_score by primary_category (bar, filter n>=100)

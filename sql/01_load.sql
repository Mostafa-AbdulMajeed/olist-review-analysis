-- ============================================================
-- Olist analysis — Stage 1: Load
-- Run:  psql -d olist -f 01_load.sql   (CSVs in the same directory)
-- Deliberately raw: no constraints, no FKs, no indexes, no cleaning.
-- ============================================================

DROP TABLE IF EXISTS customers, geolocation, order_items, order_payments,
                     order_reviews, orders, products, sellers,
                     category_translation;

CREATE TABLE customers (
    customer_id TEXT, customer_unique_id TEXT, customer_zip_code_prefix TEXT,
    customer_city TEXT, customer_state TEXT
);
CREATE TABLE geolocation (
    geolocation_zip_code_prefix TEXT, geolocation_lat NUMERIC, geolocation_lng NUMERIC,
    geolocation_city TEXT, geolocation_state TEXT
);
CREATE TABLE order_items (
    order_id TEXT, order_item_id INTEGER, product_id TEXT, seller_id TEXT,
    shipping_limit_date TIMESTAMP, price NUMERIC, freight_value NUMERIC
);
CREATE TABLE order_payments (
    order_id TEXT, payment_sequential INTEGER, payment_type TEXT,
    payment_installments INTEGER, payment_value NUMERIC
);
CREATE TABLE order_reviews (
    review_id TEXT, order_id TEXT, review_score INTEGER,
    review_comment_title TEXT, review_comment_message TEXT,
    review_creation_date TIMESTAMP, review_answer_timestamp TIMESTAMP
);
CREATE TABLE orders (
    order_id TEXT, customer_id TEXT, order_status TEXT,
    order_purchase_timestamp TIMESTAMP, order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP, order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);
CREATE TABLE products (
    product_id TEXT, product_category_name TEXT, product_name_lenght INTEGER,
    product_description_lenght INTEGER, product_photos_qty INTEGER,
    product_weight_g NUMERIC, product_length_cm NUMERIC,
    product_height_cm NUMERIC, product_width_cm NUMERIC
);
CREATE TABLE sellers (
    seller_id TEXT, seller_zip_code_prefix TEXT, seller_city TEXT, seller_state TEXT
);
CREATE TABLE category_translation (
    product_category_name TEXT, product_category_name_english TEXT
);

\copy customers            FROM 'olist_customers_dataset.csv'            WITH (FORMAT csv, HEADER true);
\copy geolocation          FROM 'olist_geolocation_dataset.csv'          WITH (FORMAT csv, HEADER true);
\copy order_items          FROM 'olist_order_items_dataset.csv'          WITH (FORMAT csv, HEADER true);
\copy order_payments       FROM 'olist_order_payments_dataset.csv'       WITH (FORMAT csv, HEADER true);
\copy order_reviews        FROM 'olist_order_reviews_dataset.csv'        WITH (FORMAT csv, HEADER true);
\copy orders               FROM 'olist_orders_dataset.csv'               WITH (FORMAT csv, HEADER true);
\copy products              FROM 'olist_products_dataset.csv'             WITH (FORMAT csv, HEADER true);
\copy sellers               FROM 'olist_sellers_dataset.csv'              WITH (FORMAT csv, HEADER true);
\copy category_translation FROM 'product_category_name_translation.csv' WITH (FORMAT csv, HEADER true);

SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;
-- Expected: 99441 / 1000163 / 112650 / 103886 / 99224 / 99441 / 32951 / 3095 / 71

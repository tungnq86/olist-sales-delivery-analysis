-- Check duplicates and missing IDs in Orders

SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    COUNT(order_id) - COUNT(DISTINCT order_id) AS duplicate_order_ids,
    COUNT(*) - COUNT(order_id) AS missing_order_ids,
    COUNT(*) - COUNT(customer_id) AS missing_customer_ids
FROM public.orders;


-- Check missing dates by order status

SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS missing_approved_dates,
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS missing_carrier_dates,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_delivery_dates
FROM public.orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- Investigate missing dates in delivered orders

SELECT
    order_id,
    order_status,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM public.orders
WHERE order_status = 'delivered'
    AND (
        order_approved_at IS NULL
        OR order_delivered_carrier_date IS NULL
        OR order_delivered_customer_date IS NULL
    )
ORDER BY order_purchase_timestamp;


-- Check chronological consistency in delivered orders

SELECT
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date < order_purchase_timestamp
    ) AS delivery_before_purchase,
	COUNT(*) FILTER (
        WHERE order_delivered_carrier_date < order_purchase_timestamp
    ) AS carrier_before_purchase,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date < order_delivered_carrier_date
    ) AS delivery_before_carrier
FROM public.orders
WHERE order_status = 'delivered';

-- Inspect orders with carrier dates before purchase dates

SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM public.orders
WHERE order_status = 'delivered'
    AND order_delivered_carrier_date < order_purchase_timestamp
ORDER BY order_purchase_timestamp
LIMIT 10;

-- Check orders without matching customers

select
COUNT(*) AS orders_without_customer
FROM public.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM public.customers c
    WHERE o.customer_id = c.customer_id
);

-- Check unmatched records across related tables
SELECT
    (SELECT COUNT(*)
     FROM public.order_items oi
     WHERE NOT EXISTS (
         SELECT 1
         FROM public.orders o
         WHERE oi.order_id = o.order_id
     )) AS items_without_order,
    (SELECT COUNT(*)
     FROM public.order_items oi
     WHERE NOT EXISTS (
         SELECT 1
         FROM public.products p
         WHERE oi.product_id = p.product_id
     )) AS items_without_product,
    (SELECT COUNT(*)
     FROM public.products p
     WHERE p.product_category_name IS NOT NULL
       AND NOT EXISTS (
         SELECT 1
         FROM public.category_translation t
         WHERE p.product_category_name = t.product_category_name
     )) AS products_without_translation;


-- Identify product categories without English translations

SELECT
    p.product_category_name,
    COUNT(*) AS total_products
FROM public.products p
LEFT JOIN public.category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
    AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY total_products DESC;
-- Check NULL vs empty product categories

SELECT
    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS null_categories,
    COUNT(*) FILTER (
        WHERE product_category_name IS NOT NULL
          AND TRIM(product_category_name) = ''
    ) AS empty_categories
FROM public.products;

-- Check duplicate keys across tables

SELECT
    (SELECT COUNT(*) - COUNT(DISTINCT customer_id)
     FROM public.customers) AS duplicate_customer_ids,
    (SELECT COUNT(*) - COUNT(DISTINCT product_id)
     FROM public.products) AS duplicate_product_ids,
    (SELECT COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
     FROM public.order_items) AS duplicate_order_item_keys,
    (SELECT COUNT(*) - COUNT(DISTINCT product_category_name)
     FROM public.category_translation) AS duplicate_category_keys;

SELECT
    product_id,
    '[' || product_category_name || ']' AS category,
    LENGTH(product_category_name) AS category_length
FROM public.products
WHERE TRIM(product_category_name) = ''
LIMIT 10;







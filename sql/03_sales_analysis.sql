-- Sales Performance: Overall KPIs
-- Initial exploration: all available delivered orders
-- Dashboard reporting period is validated separately
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(*) AS total_order_items,
    ROUND(SUM(oi.price), 2) AS merchandise_sales,
    ROUND(
        SUM(oi.price) / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS avg_order_value
FROM public.orders o
INNER JOIN public.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- Sales Performance: Monthly Sales Trends
-- Initial exploration: full available date range
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS merchandise_sales,
    ROUND(
        SUM(oi.price) / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS avg_order_value
FROM public.orders o
INNER JOIN public.order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)::DATE
ORDER BY order_month;

-- Check data coverage in the final months
SELECT
    DATE_TRUNC('month', order_purchase_timestamp)::DATE AS order_month,
    COUNT(*) AS all_orders,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS delivered_percentage,
    MAX(order_purchase_timestamp)::DATE AS last_purchase_date
FROM public.orders
WHERE order_purchase_timestamp >= '2018-07-01'
GROUP BY 1
ORDER BY 1;

-- Monthly Sales Growth (MoM)
-- Analysis period: Jan 2017 - Aug 2018
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS merchandise_sales
    FROM public.orders o
    INNER JOIN public.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY 1
),
sales_growth AS (
    SELECT
        order_month,
        total_orders,
        merchandise_sales,
        LAG(merchandise_sales) OVER (
            ORDER BY order_month
        ) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    order_month,
    total_orders,
    ROUND(merchandise_sales, 2) AS merchandise_sales,
    ROUND(
        100.0 * (merchandise_sales - previous_month_sales)
        / NULLIF(previous_month_sales, 0),
        2
    ) AS mom_growth_pct
FROM sales_growth
ORDER BY order_month;

-- Sales Performance: Top 10 Product Categories
-- Analysis period: Jan 2017 - Aug 2018
SELECT
    COALESCE(
        NULLIF(TRIM(t.product_category_name_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown'
    ) AS product_category,
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS merchandise_sales
FROM public.orders o
INNER JOIN public.order_items oi
    ON o.order_id = oi.order_id
LEFT JOIN public.products p
    ON oi.product_id = p.product_id
LEFT JOIN public.category_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY 1
ORDER BY merchandise_sales DESC
LIMIT 10;

-- Product Category: Sales Contribution & Average Item Price
WITH category_sales AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(t.product_category_name_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        ) AS product_category,
        COUNT(*) AS total_order_items,
        SUM(oi.price) AS merchandise_sales
    FROM public.orders o
    INNER JOIN public.order_items oi
        ON o.order_id = oi.order_id
    LEFT JOIN public.products p
        ON oi.product_id = p.product_id
    LEFT JOIN public.category_translation t
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY 1
)
SELECT
    product_category,
    total_order_items,
    ROUND(merchandise_sales, 2) AS merchandise_sales,
    ROUND(
        merchandise_sales / NULLIF(total_order_items, 0),
        2
    ) AS avg_item_price,
    ROUND(
        100.0 * merchandise_sales
        / NULLIF(SUM(merchandise_sales) OVER (), 0),
        2
    ) AS sales_contribution_pct
FROM category_sales
ORDER BY merchandise_sales DESC
LIMIT 10;

-- Regional Sales Performance
-- Analysis period: Jan 2017 - Aug 2018
WITH regional_sales AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS merchandise_sales
    FROM public.orders o
    INNER JOIN public.order_items oi
        ON o.order_id = oi.order_id
    INNER JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_state
)
SELECT
    customer_state,
    total_orders,
    ROUND(merchandise_sales, 2) AS merchandise_sales,
    ROUND(
        merchandise_sales / NULLIF(total_orders, 0),
        2
    ) AS avg_order_value,
    ROUND(
        100.0 * merchandise_sales
        / NULLIF(SUM(merchandise_sales) OVER (), 0),
        2
    ) AS sales_contribution_pct
FROM regional_sales
ORDER BY merchandise_sales DESC
LIMIT 10;








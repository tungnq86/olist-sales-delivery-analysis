
-- Commercial Exposure: Overall KPIs
-- Analysis period: Jan 2017 - Aug 2018
WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.order_items
    GROUP BY order_id
),
delivery_orders AS (
    SELECT
        order_id,
        CASE
            WHEN order_delivered_customer_date::date
                 > order_estimated_delivery_date::date
            THEN 1
            ELSE 0
        END AS is_late
    FROM public.orders
    WHERE order_status = 'delivered'
        AND order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-09-01'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    COUNT(*) AS valid_delivered_orders,
    COUNT(*) FILTER (
        WHERE d.is_late = 1
    ) AS late_orders,
    ROUND(SUM(COALESCE(s.merchandise_value, 0)), 2)
        AS total_merchandise_sales,
    ROUND(
        SUM(COALESCE(s.merchandise_value, 0))
        FILTER (WHERE d.is_late = 1),
        2
    ) AS late_order_merchandise_value,
    ROUND(
        100.0 *
        SUM(COALESCE(s.merchandise_value, 0))
            FILTER (WHERE d.is_late = 1)
        / NULLIF(SUM(COALESCE(s.merchandise_value, 0)), 0),
        2
    ) AS late_sales_exposure_pct
FROM delivery_orders d
LEFT JOIN order_sales s
    ON d.order_id = s.order_id;


-- Commercial Exposure by Region
-- Analysis period: Jan 2017 - Aug 2018
WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.order_items
    GROUP BY order_id
),
delivery_orders AS (
    SELECT
        o.order_id,
        c.customer_state,
        CASE
            WHEN o.order_delivered_customer_date::date
                 > o.order_estimated_delivery_date::date
            THEN 1
            ELSE 0
        END AS is_late
    FROM public.orders o
    INNER JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
),
regional_exposure AS (
    SELECT
        d.customer_state,
        COUNT(*) AS valid_delivered_orders,
        COUNT(*) FILTER (
            WHERE d.is_late = 1
        ) AS late_orders,
        SUM(COALESCE(s.merchandise_value, 0))
            AS merchandise_sales,
        SUM(
            CASE
                WHEN d.is_late = 1
                THEN COALESCE(s.merchandise_value, 0)
                ELSE 0
            END
        ) AS late_order_value
    FROM delivery_orders d
    LEFT JOIN order_sales s
        ON d.order_id = s.order_id
    GROUP BY d.customer_state
)
SELECT
    customer_state,
    valid_delivered_orders,
    late_orders,
    ROUND(merchandise_sales, 2)
        AS merchandise_sales,
    ROUND(late_order_value, 2)
        AS late_order_value,
    ROUND(
        100.0 * late_orders
        / NULLIF(valid_delivered_orders, 0),
        2
    ) AS late_order_rate_pct,
    ROUND(
        100.0 * late_order_value
        / NULLIF(merchandise_sales, 0),
        2
    ) AS late_sales_exposure_pct,
    ROUND(
        100.0 * late_order_value
        / NULLIF(SUM(late_order_value) OVER (), 0),
        2
    ) AS share_of_total_late_sales_pct
FROM regional_exposure
ORDER BY late_order_value DESC
LIMIT 10;

-- Delivery Delay Segmentation
-- Analysis period: Jan 2017 - Aug 2018
WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.order_items
    GROUP BY order_id
),
valid_deliveries AS (
    SELECT
        order_id,
        order_delivered_customer_date::date
        - order_estimated_delivery_date::date
            AS delay_days
    FROM public.orders
    WHERE order_status = 'delivered'
        AND order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-09-01'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
),
classified_orders AS (
    SELECT
        d.order_id,
        d.delay_days,
        COALESCE(s.merchandise_value, 0)
            AS merchandise_value,
        CASE
            WHEN d.delay_days <= 0 THEN 'On-time / Early'
            WHEN d.delay_days BETWEEN 1 AND 3 THEN 'Late 1-3 Days'
            WHEN d.delay_days BETWEEN 4 AND 7 THEN 'Late 4-7 Days'
            ELSE 'Late 8+ Days'
        END AS delay_bucket,
        CASE
            WHEN d.delay_days <= 0 THEN 1
            WHEN d.delay_days BETWEEN 1 AND 3 THEN 2
            WHEN d.delay_days BETWEEN 4 AND 7 THEN 3
            ELSE 4
        END AS bucket_order
    FROM valid_deliveries d
    LEFT JOIN order_sales s
        ON d.order_id = s.order_id
),
bucket_summary AS (
    SELECT
        delay_bucket,
        bucket_order,
        COUNT(*) AS total_orders,
        ROUND(SUM(merchandise_value), 2)
            AS merchandise_sales,
        ROUND(AVG(merchandise_value), 2)
            AS avg_order_value
    FROM classified_orders
    GROUP BY delay_bucket, bucket_order
)
SELECT
    delay_bucket,
    total_orders,
    ROUND(
        100.0 * total_orders
        / NULLIF(SUM(total_orders) OVER (), 0),
        2
    ) AS order_share_pct,
    merchandise_sales,
    ROUND(
        100.0 * merchandise_sales
        / NULLIF(SUM(merchandise_sales) OVER (), 0),
        2
    ) AS sales_share_pct,
    avg_order_value
FROM bucket_summary
ORDER BY bucket_order;



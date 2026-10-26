
-- Delivery Performance: Overall KPIs
-- Analysis period: Jan 2017 - Aug 2018
WITH valid_deliveries AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date
    FROM public.orders
    WHERE order_status = 'delivered'
        AND order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-09-01'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
        AND order_delivered_customer_date >= order_purchase_timestamp
)
SELECT
    COUNT(*) AS total_delivered_orders,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )) / 86400
        ), 2
    ) AS avg_delivery_days,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date::DATE
            <= order_estimated_delivery_date::DATE
    ) AS on_time_orders,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date::DATE
            > order_estimated_delivery_date::DATE
    ) AS late_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_delivered_customer_date::DATE
                <= order_estimated_delivery_date::DATE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_pct
FROM valid_deliveries;

-- Delivery Performance by Region
-- Analysis period: Jan 2017 - Aug 2018
WITH valid_deliveries AS (
    SELECT
        o.order_id,
        c.customer_state,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM public.orders o
    INNER JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
        AND o.order_delivered_customer_date >= o.order_purchase_timestamp
)
SELECT
    customer_state,
    COUNT(*) AS total_delivered_orders,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )) / 86400
        ), 2
    ) AS avg_delivery_days,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date::DATE
            > order_estimated_delivery_date::DATE
    ) AS late_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_delivered_customer_date::DATE
                <= order_estimated_delivery_date::DATE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_pct
FROM valid_deliveries
GROUP BY customer_state
ORDER BY total_delivered_orders DESC
LIMIT 10;

-- Sales vs Delivery Performance by Region
-- Analysis period: Jan 2017 - Aug 2018
WITH regional_sales AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS merchandise_sales
    FROM public.orders o
    JOIN public.order_items oi
        ON o.order_id = oi.order_id
    JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_state
),
regional_delivery AS (
    SELECT
        c.customer_state,
        COUNT(*) AS valid_delivered_orders,
        COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date::DATE
                > o.order_estimated_delivery_date::DATE
        ) AS late_orders,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE o.order_delivered_customer_date::DATE
                    <= o.order_estimated_delivery_date::DATE
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS on_time_delivery_pct
    FROM public.orders o
    JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
        AND o.order_delivered_customer_date >= o.order_purchase_timestamp
    GROUP BY c.customer_state
)
SELECT
    s.customer_state,
    s.total_orders,
    ROUND(s.merchandise_sales, 2) AS merchandise_sales,
    ROUND(
        100.0 * s.merchandise_sales
        / NULLIF(SUM(s.merchandise_sales) OVER (), 0),
        2
    ) AS sales_contribution_pct,
    d.valid_delivered_orders,
    d.late_orders,
    d.on_time_delivery_pct
FROM regional_sales s
JOIN regional_delivery d
    ON s.customer_state = d.customer_state
ORDER BY s.merchandise_sales DESC
LIMIT 10;



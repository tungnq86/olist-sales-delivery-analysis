
-- Q5: Regional Business Prioritization
-- Combine Delivery Reliability, Commercial Exposure
-- and Customer Satisfaction
WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.order_items
    GROUP BY order_id
),
order_level AS (
    SELECT
        o.order_id,
        c.customer_state,
        (o.order_delivered_customer_date::date
         > o.order_estimated_delivery_date::date)
            AS is_late,
        COALESCE(s.merchandise_value, 0)
            AS merchandise_value,
        r.review_score
    FROM public.orders o
    INNER JOIN public.customers c
        ON o.customer_id = c.customer_id
    LEFT JOIN order_sales s
        ON o.order_id = s.order_id
    LEFT JOIN public.order_reviews_latest r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
	AND o.order_delivered_customer_date >= o.order_purchase_timestamp
),
regional_summary AS (
    SELECT
        customer_state,
        COUNT(*) AS valid_delivered_orders,
        COUNT(*) FILTER (
            WHERE is_late
        ) AS late_orders,
        SUM(merchandise_value)
            AS merchandise_sales,
        SUM(merchandise_value) FILTER (
            WHERE is_late
        ) AS late_order_value,
        COUNT(review_score) FILTER (
            WHERE is_late
        ) AS late_reviewed_orders,
        COUNT(*) FILTER (
            WHERE is_late
              AND review_score BETWEEN 1 AND 2
        ) AS late_low_rating_orders
    FROM order_level
    GROUP BY customer_state
)
SELECT
    customer_state,
    valid_delivered_orders,
    late_orders,
    ROUND(
        100.0 * late_orders
        / NULLIF(valid_delivered_orders, 0), 2
    ) AS late_order_rate_pct,
    ROUND(late_order_value, 2)
        AS late_order_value,
    ROUND(
        100.0 * late_order_value
        / NULLIF(merchandise_sales, 0), 2
    ) AS late_sales_exposure_pct,
    ROUND(
        100.0 * late_order_value
        / NULLIF(SUM(late_order_value) OVER (), 0), 2
    ) AS share_of_total_late_sales_pct,
    late_reviewed_orders,
    late_low_rating_orders,
    ROUND(
        100.0 * late_low_rating_orders
        / NULLIF(late_reviewed_orders, 0), 2
    ) AS late_low_rating_pct
FROM regional_summary
ORDER BY late_order_value DESC;

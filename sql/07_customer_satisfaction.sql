
-- Customer Satisfaction Analysis
-- Review Score by Delivery Delay
-- Analysis period: Jan 2017 - Aug 2018
WITH valid_deliveries AS (
    SELECT
        order_id,
        order_delivered_customer_date::date
        - order_estimated_delivery_date::date AS delay_days
    FROM public.orders
    WHERE order_status = 'delivered'
        AND order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-09-01'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
),
classified_orders AS (
    SELECT
        order_id,
        CASE
            WHEN delay_days <= 0 THEN 'On-time / Early'
            WHEN delay_days BETWEEN 1 AND 3 THEN 'Late 1-3 Days'
            WHEN delay_days BETWEEN 4 AND 7 THEN 'Late 4-7 Days'
            ELSE 'Late 8+ Days'
        END AS delay_bucket,
        CASE
            WHEN delay_days <= 0 THEN 1
            WHEN delay_days BETWEEN 1 AND 3 THEN 2
            WHEN delay_days BETWEEN 4 AND 7 THEN 3
            ELSE 4
        END AS bucket_order
    FROM valid_deliveries
)
SELECT
    d.delay_bucket,
    COUNT(*) AS total_orders,
    COUNT(r.review_score) AS reviewed_orders,
    ROUND(
        100.0 * COUNT(r.review_score)
        / NULLIF(COUNT(*), 0),
        2
    ) AS review_coverage_pct,
    ROUND(AVG(r.review_score), 2)
        AS avg_review_score,
    COUNT(*) FILTER (
        WHERE r.review_score BETWEEN 1 AND 2
    ) AS low_rating_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE r.review_score BETWEEN 1 AND 2
        )
        / NULLIF(COUNT(r.review_score), 0),
        2
    ) AS low_rating_pct
FROM classified_orders d
LEFT JOIN public.order_reviews_latest r
    ON d.order_id = r.order_id
GROUP BY d.delay_bucket, d.bucket_order
ORDER BY d.bucket_order;

-- Customer Satisfaction by Region
-- Compare low ratings for on-time vs late orders
WITH delivery_reviews AS (
    SELECT
        o.order_id,
        c.customer_state,
        (
            o.order_delivered_customer_date::date
            > o.order_estimated_delivery_date::date
        ) AS is_late,
        r.review_score
    FROM public.orders o
    INNER JOIN public.customers c
        ON o.customer_id = c.customer_id
    LEFT JOIN public.order_reviews_latest r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp < '2018-09-01'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
),
regional_summary AS (
    SELECT
        customer_state,
        COUNT(*) AS valid_delivered_orders,
        COUNT(*) FILTER (
            WHERE is_late
        ) AS late_orders,
        COUNT(review_score) FILTER (
            WHERE NOT is_late
        ) AS on_time_reviewed_orders,
        COUNT(review_score) FILTER (
            WHERE is_late
        ) AS late_reviewed_orders,
        COUNT(*) FILTER (
            WHERE NOT is_late
              AND review_score BETWEEN 1 AND 2
        ) AS on_time_low_reviews,
        COUNT(*) FILTER (
            WHERE is_late
              AND review_score BETWEEN 1 AND 2
        ) AS late_low_reviews
    FROM delivery_reviews
    GROUP BY customer_state
)
SELECT
    customer_state,
    valid_delivered_orders,
    late_orders,
    late_reviewed_orders,
    ROUND(
        100.0 * late_orders
        / NULLIF(valid_delivered_orders, 0), 2
    ) AS late_order_rate_pct,
    ROUND(
        100.0 * on_time_low_reviews
        / NULLIF(on_time_reviewed_orders, 0), 2
    ) AS on_time_low_rating_pct,
    ROUND(
        100.0 * late_low_reviews
        / NULLIF(late_reviewed_orders, 0), 2
    ) AS late_low_rating_pct
FROM regional_summary
ORDER BY valid_delivered_orders DESC
LIMIT 10;


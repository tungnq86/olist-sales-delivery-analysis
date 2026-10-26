
-- Review Data Quality: Missing Values & Duplicate IDs
SELECT
    COUNT(*) AS total_reviews,
    COUNT(*) - COUNT(order_id)
        AS missing_order_ids,
    COUNT(*) - COUNT(review_id)
        AS missing_review_ids,
    COUNT(*) - COUNT(review_score)
        AS missing_review_scores,
    COUNT(*) FILTER (
        WHERE review_score NOT BETWEEN 1 AND 5
    ) AS invalid_review_scores,
    COUNT(order_id) - COUNT(DISTINCT order_id)
        AS repeated_order_rows,
    COUNT(review_id) - COUNT(DISTINCT review_id)
        AS repeated_review_id_rows
FROM public.order_reviews;

-- Investigate orders with multiple review records
SELECT
    order_id,
    COUNT(*) AS review_records,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(DISTINCT review_score) AS distinct_scores
FROM public.order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_records DESC, order_id
LIMIT 20;

-- Investigate review IDs appearing multiple times
SELECT
    review_id,
    COUNT(*) AS review_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT review_score) AS distinct_scores
FROM public.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY distinct_orders DESC, review_records DESC
LIMIT 20;


-- Classify repeated Review IDs
WITH repeated_reviews AS (
    SELECT
        review_id,
        COUNT(*) AS review_records,
        COUNT(DISTINCT order_id) AS distinct_orders
    FROM public.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS repeated_review_ids,
    COUNT(*) FILTER (
        WHERE distinct_orders = 1
    ) AS repeated_within_same_order,
    COUNT(*) FILTER (
        WHERE distinct_orders > 1
    ) AS shared_across_orders,
    SUM(review_records - 1) AS extra_review_rows
FROM repeated_reviews;

-- Final Reviews Data Integrity Checks
WITH order_summary AS (
    SELECT
        order_id,
        COUNT(*) AS review_records,
        COUNT(DISTINCT review_score) AS distinct_scores
    FROM public.order_reviews
    GROUP BY order_id
),
review_pairs AS (
    SELECT
        order_id,
        review_id,
        COUNT(*) AS pair_records
    FROM public.order_reviews
    GROUP BY order_id, review_id
)
SELECT
    (SELECT COUNT(*)
     FROM order_summary
     WHERE review_records > 1)
        AS orders_with_multiple_reviews,
    (SELECT COUNT(*)
     FROM order_summary
     WHERE distinct_scores > 1)
        AS orders_with_different_scores,
    (SELECT COUNT(*)
     FROM review_pairs
     WHERE pair_records > 1)
        AS duplicate_order_review_pairs,
    (SELECT COUNT(*)
     FROM public.order_reviews r
     WHERE NOT EXISTS (
         SELECT 1
         FROM public.orders o
         WHERE o.order_id = r.order_id
     ))
        AS reviews_without_order,
    (SELECT COUNT(*)
     FROM public.order_reviews
     WHERE review_answer_timestamp IS NULL)
        AS missing_answer_timestamps;

-- Create an order-level Reviews View
-- Keep the latest review for each order
CREATE OR REPLACE VIEW public.order_reviews_latest AS
WITH ranked_reviews AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                review_answer_timestamp DESC,
                review_creation_date DESC,
                review_id DESC
        ) AS review_rank
    FROM public.order_reviews
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM ranked_reviews
WHERE review_rank = 1;

-- Validate the order-level Reviews View
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(*) - COUNT(DISTINCT order_id)
        AS duplicate_orders
FROM public.order_reviews_latest;

-- Check Review Coverage for Delivered Orders
-- Analysis period: Jan 2017 - Aug 2018
SELECT
    COUNT(*) AS total_delivered_orders,
    COUNT(r.order_id) AS reviewed_orders,
    COUNT(*) FILTER (
        WHERE r.order_id IS NULL
    ) AS orders_without_review,
    ROUND(
        100.0 * COUNT(r.order_id)
        / NULLIF(COUNT(*), 0),
        2
    ) AS review_coverage_pct
FROM public.orders o
LEFT JOIN public.order_reviews_latest r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2018-09-01';







-- =====================================================
-- 09 | KPI DEFINITIONS & DATA RECONCILIATION
-- Optimized version
-- Database: olist_ecom
-- =====================================================
WITH item_orders AS (
    SELECT DISTINCT order_id
    FROM public.order_items
),
review_orders AS (
    SELECT DISTINCT order_id
    FROM public.order_reviews_latest
),
order_flags AS (
    SELECT
        o.order_id,
        -- KPI 1: Sales
        (
            o.order_status = 'delivered'
            AND i.order_id IS NOT NULL
        ) AS in_total_orders,
        -- KPI 2: Delivery
        (
            o.order_status = 'delivered'
            AND o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL
            AND o.order_delivered_customer_date
                >= o.order_purchase_timestamp
        ) AS in_valid_delivered,
        -- KPI 3: Customer Reviews
        (
            o.order_status = 'delivered'
            AND r.order_id IS NOT NULL
            AND o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL
        ) AS in_reviewed_delivered
    FROM public.orders o
    LEFT JOIN item_orders i
        ON o.order_id = i.order_id
    LEFT JOIN review_orders r
        ON o.order_id = r.order_id
    WHERE o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp < TIMESTAMP '2018-09-01'
)
SELECT
    COUNT(*) FILTER (
        WHERE in_total_orders
    ) AS total_orders,
    COUNT(*) FILTER (
        WHERE in_valid_delivered
    ) AS valid_delivered_orders,
    COUNT(*) FILTER (
        WHERE in_reviewed_delivered
    ) AS reviewed_delivered_orders,
    COUNT(*) FILTER (
        WHERE in_total_orders
          AND NOT in_valid_delivered
    ) AS total_not_valid,
    COUNT(*) FILTER (
        WHERE in_valid_delivered
          AND NOT in_total_orders
    ) AS valid_not_in_total,
    COUNT(*) FILTER (
        WHERE in_valid_delivered
          AND NOT in_reviewed_delivered
    ) AS valid_not_reviewed,
    COUNT(*) FILTER (
        WHERE in_reviewed_delivered
          AND NOT in_valid_delivered
    ) AS reviewed_not_valid
FROM order_flags;


-- 09.2 | Investigate invalid delivery records
SELECT
    o.order_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN 'Missing actual delivery date'
        WHEN o.order_estimated_delivery_date IS NULL
            THEN 'Missing estimated delivery date'
        WHEN o.order_delivered_customer_date
             < o.order_purchase_timestamp
            THEN 'Delivered before purchase'
        ELSE 'Other'
    END AS invalid_reason
FROM public.orders o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'
  AND EXISTS (
      SELECT 1
      FROM public.order_items oi
      WHERE oi.order_id = o.order_id
  )
  AND (
      o.order_delivered_customer_date IS NULL
      OR o.order_estimated_delivery_date IS NULL
      OR o.order_delivered_customer_date
         < o.order_purchase_timestamp
  )
ORDER BY invalid_reason, o.order_id;


-- =====================================================
-- 09.3 | SALES KPI RECONCILIATION
-- Database: olist_ecom
-- Period: Jan 2017 - Aug 2018
--
-- Validate:
-- 1. Total Orders
-- 2. Merchandise Sales
-- 3. Average Order Value
-- =====================================================
WITH sales_base AS (
    SELECT
        o.order_id,
        oi.order_item_id,
        oi.price
    FROM public.orders o
    INNER JOIN public.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp < TIMESTAMP '2018-09-01'
),
sales_kpis AS (
    SELECT
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(price)::numeric AS merchandise_sales
    FROM sales_base
)
SELECT
    total_orders,
    ROUND(
        merchandise_sales, 2
    ) AS merchandise_sales,
    ROUND(
        merchandise_sales / NULLIF(total_orders, 0), 2
    ) AS average_order_value,
    ROUND(
        merchandise_sales / 1000000, 2
    ) AS merchandise_sales_millions
FROM sales_kpis;


-- =====================================================
-- 09.4 | SALES ANALYSIS BATCH VALIDATION
-- Database: olist_ecom
-- Period: Jan 2017 - Aug 2018
--
-- Validates:
-- 1. Overall Sales
-- 2. Monthly Sales Trend
-- 3. Top 10 Product Categories
-- 4. Top 10 States
-- 5. Regional Sales Contribution %
-- =====================================================
WITH sales_base AS (
    SELECT
        o.order_id,
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::date AS purchase_month,
        oi.price::numeric AS merchandise_value,
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        COALESCE(
            c.customer_state,
            'Unknown'
        ) AS customer_state
    FROM public.orders o
    INNER JOIN public.order_items oi
        ON o.order_id = oi.order_id
    LEFT JOIN public.customers c
        ON o.customer_id = c.customer_id
    LEFT JOIN public.products p
        ON oi.product_id = p.product_id
    LEFT JOIN public.category_translation ct
        ON p.product_category_name =
           ct.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp
          >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp
          < TIMESTAMP '2018-09-01'
),
-- Overall sales
overall AS (
    SELECT
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(merchandise_value) AS total_sales
    FROM sales_base
),
-- Monthly performance
monthly_sales AS (
    SELECT
        TO_CHAR(purchase_month, 'YYYY-MM') AS period,
        COUNT(DISTINCT order_id) AS orders,
        SUM(merchandise_value) AS sales
    FROM sales_base
    GROUP BY purchase_month
),
-- Product category performance
category_sales AS (
    SELECT
        product_category,
        COUNT(DISTINCT order_id) AS orders,
        SUM(merchandise_value) AS sales
    FROM sales_base
    GROUP BY product_category
),
category_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY sales DESC, product_category
        ) AS ranking
    FROM category_sales
),
-- Regional performance
regional_sales AS (
    SELECT
        customer_state,
        COUNT(DISTINCT order_id) AS orders,
        SUM(merchandise_value) AS sales
    FROM sales_base
    GROUP BY customer_state
),
regional_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY sales DESC, customer_state
        ) AS ranking
    FROM regional_sales
),
-- Consolidated validation output
validation_results AS (
    SELECT
        1 AS section_order,
        0 AS sort_order,
        'OVERALL SALES' AS section,
        'All delivered orders' AS dimension,
        NULL::bigint AS ranking,
        total_orders AS order_count,
        ROUND(total_sales, 2) AS merchandise_sales,
        100.00::numeric AS sales_share_pct
    FROM overall
    UNION ALL
    SELECT
        2,
        0,
        'MONTHLY SALES',
        m.period,
        NULL::bigint,
        m.orders,
        ROUND(m.sales, 2),
        ROUND(
            100.0 * m.sales / NULLIF(o.total_sales, 0),
            2
        )
    FROM monthly_sales m
    CROSS JOIN overall o
    UNION ALL
    SELECT
        3,
        c.ranking::integer,
        'TOP 10 CATEGORIES',
        c.product_category,
        c.ranking,
        c.orders,
        ROUND(c.sales, 2),
        ROUND(
            100.0 * c.sales / NULLIF(o.total_sales, 0),
            2
        )
    FROM category_ranked c
    CROSS JOIN overall o
    WHERE c.ranking <= 10
    UNION ALL
    SELECT
        4,
        r.ranking::integer,
        'TOP 10 STATES',
        r.customer_state,
        r.ranking,
        r.orders,
        ROUND(r.sales, 2),
        ROUND(
            100.0 * r.sales / NULLIF(o.total_sales, 0),
            2
        )
    FROM regional_ranked r
    CROSS JOIN overall o
    WHERE r.ranking <= 10
)
SELECT
    section,
    dimension,
    ranking,
    order_count,
    merchandise_sales,
    sales_share_pct
FROM validation_results
ORDER BY
    section_order,
    CASE
        WHEN section_order = 2 THEN dimension
        ELSE NULL
    END,
    sort_order;


-- =====================================================
-- 09.5 | DELIVERY PERFORMANCE BATCH VALIDATION
-- Database: olist_ecom
-- Period: Jan 2017 - Aug 2018
-- =====================================================
WITH delivery_base AS (
    SELECT
        o.order_id,
        DATE_TRUNC(
            'month', o.order_purchase_timestamp
        )::date AS purchase_month,
        c.customer_state,
        -- Match DAX Delivery Delay Days
        (
            o.order_delivered_customer_date::date
            - o.order_estimated_delivery_date::date
        ) AS delay_days,
        -- Delivery duration using exact timestamps
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date
            - o.order_purchase_timestamp
        )) / 86400.0 AS delivery_days_exact,
        -- Alternative: calendar-day difference
        (
            o.order_delivered_customer_date::date
            - o.order_purchase_timestamp::date
        ) AS delivery_days_calendar
    FROM public.orders o
    LEFT JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND o.order_delivered_customer_date
          >= o.order_purchase_timestamp
),
overall AS (
    SELECT
        COUNT(*) AS valid_orders,
        COUNT(*) FILTER (
            WHERE delay_days > 0
        ) AS late_orders,
        COUNT(*) FILTER (
            WHERE delay_days <= 0
        ) AS on_time_orders,
        AVG(delivery_days_exact) AS avg_exact,
        AVG(delivery_days_calendar) AS avg_calendar
    FROM delivery_base
),
monthly AS (
    SELECT
        TO_CHAR(purchase_month, 'YYYY-MM') AS period,
        COUNT(*) AS valid_orders,
        COUNT(*) FILTER (
            WHERE delay_days > 0
        ) AS late_orders,
        COUNT(*) FILTER (
            WHERE delay_days <= 0
        ) AS on_time_orders,
        AVG(delivery_days_exact) AS avg_exact,
        AVG(delivery_days_calendar) AS avg_calendar
    FROM delivery_base
    GROUP BY purchase_month
),
regional AS (
    SELECT
        customer_state,
        COUNT(*) AS valid_orders,
        COUNT(*) FILTER (
            WHERE delay_days > 0
        ) AS late_orders,
        COUNT(*) FILTER (
            WHERE delay_days <= 0
        ) AS on_time_orders,
        AVG(delivery_days_exact) AS avg_exact,
        AVG(delivery_days_calendar) AS avg_calendar
    FROM delivery_base
    GROUP BY customer_state
),
regional_ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY valid_orders DESC, customer_state
        ) AS ranking
    FROM regional
),
severity AS (
    SELECT
        CASE
            WHEN delay_days BETWEEN 1 AND 3
                THEN 'Late 1-3 Days'
            WHEN delay_days BETWEEN 4 AND 7
                THEN 'Late 4-7 Days'
            WHEN delay_days >= 8
                THEN 'Late 8+ Days'
        END AS severity_bucket,
        COUNT(*) AS orders
    FROM delivery_base
    WHERE delay_days > 0
    GROUP BY 1
),
results AS (
    -- Overall KPIs
    SELECT
        1 AS section_order,
        0 AS sort_order,
        'OVERALL DELIVERY' AS section,
        'All valid delivered orders' AS dimension,
        valid_orders,
        late_orders,
        ROUND(
            100.0 * on_time_orders
            / NULLIF(valid_orders, 0), 2
        ) AS on_time_rate_pct,
        ROUND(avg_exact::numeric, 2)
            AS avg_delivery_days_exact,
        ROUND(avg_calendar::numeric, 2)
            AS avg_delivery_days_calendar,
        NULL::numeric AS late_share_pct
    FROM overall
    UNION ALL
    -- Monthly performance
    SELECT
        2, 0,
        'MONTHLY DELIVERY',
        period,
        valid_orders,
        late_orders,
        ROUND(
            100.0 * on_time_orders
            / NULLIF(valid_orders, 0), 2
        ),
        ROUND(avg_exact::numeric, 2),
        ROUND(avg_calendar::numeric, 2),
        NULL::numeric
    FROM monthly
    UNION ALL
    -- Late delivery severity
    SELECT
        3,
        CASE severity_bucket
            WHEN 'Late 1-3 Days' THEN 1
            WHEN 'Late 4-7 Days' THEN 2
            ELSE 3
        END,
        'LATE SEVERITY',
        severity_bucket,
        NULL::bigint,
        orders,
        NULL::numeric,
        NULL::numeric,
        NULL::numeric,
        ROUND(
            100.0 * orders
            / NULLIF(o.late_orders, 0), 2
        )
    FROM severity
    CROSS JOIN overall o
    UNION ALL
    -- Regional performance
    SELECT
        4,
        ranking::integer,
        'TOP 10 STATES',
        customer_state,
        valid_orders,
        late_orders,
        ROUND(
            100.0 * on_time_orders
            / NULLIF(valid_orders, 0), 2
        ),
        ROUND(avg_exact::numeric, 2),
        ROUND(avg_calendar::numeric, 2),
        NULL::numeric
    FROM regional_ranked
    WHERE ranking <= 10
)
SELECT
    section,
    dimension,
    valid_orders,
    late_orders,
    on_time_rate_pct,
    avg_delivery_days_exact,
    avg_delivery_days_calendar,
    late_share_pct
FROM results
ORDER BY
    section_order,
    CASE
        WHEN section_order = 2 THEN dimension
        ELSE NULL
    END,
    sort_order;


-- =====================================================
-- 09.6 | CUSTOMER IMPACT BATCH VALIDATION
-- Project: E-commerce Sales & Delivery Analysis
-- Database: olist_ecom
-- Period: Jan 2017 - Aug 2018
-- =====================================================
WITH order_values AS (
    SELECT
        order_id,
        SUM(price)::numeric AS merchandise_value
    FROM public.order_items
    GROUP BY order_id
),
base AS (
    SELECT
        o.order_id,
        c.customer_state,
        r.review_score,
        (r.order_id IS NOT NULL) AS has_review,
        (
            o.order_delivered_customer_date::date
            - o.order_estimated_delivery_date::date
        ) AS delay_days,
        COALESCE(
            v.merchandise_value, 0
        ) AS merchandise_value
    FROM public.orders o
    LEFT JOIN public.customers c
        ON o.customer_id = c.customer_id
    LEFT JOIN public.order_reviews_latest r
        ON o.order_id = r.order_id
    LEFT JOIN order_values v
        ON o.order_id = v.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp
          >= TIMESTAMP '2017-01-01'
      AND o.order_purchase_timestamp
          < TIMESTAMP '2018-09-01'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND o.order_delivered_customer_date
          >= o.order_purchase_timestamp
),
bucketed AS (
    SELECT
        *,
        CASE
            WHEN delay_days <= 0
                THEN 'On-time / Early'
            WHEN delay_days BETWEEN 1 AND 3
                THEN 'Late 1-3 Days'
            WHEN delay_days BETWEEN 4 AND 7
                THEN 'Late 4-7 Days'
            WHEN delay_days >= 8
                THEN 'Late 8+ Days'
        END AS delay_bucket
    FROM base
),
scopes AS (
    SELECT
        1 AS section_order,
        'OVERALL CUSTOMER' AS section,
        'All Orders' AS dimension,
        b.*
    FROM bucketed b
    UNION ALL
    SELECT
        2,
        'DELIVERY DELAY',
        b.delay_bucket,
        b.*
    FROM bucketed b
    UNION ALL
    SELECT
        3,
        'REGIONAL CUSTOMER',
        COALESCE(b.customer_state, 'Unknown'),
        b.*
    FROM bucketed b
),
metrics AS (
    SELECT
        section_order,
        section,
        dimension,
        COUNT(*) AS valid_orders,
        COUNT(*) FILTER (
            WHERE has_review
        ) AS reviewed_orders,
        ROUND(
            AVG(review_score)::numeric, 2
        ) AS avg_review_score,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE has_review
                  AND review_score <= 2
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE has_review
                ), 0
            ), 2
        ) AS low_rating_pct,
        COUNT(*) FILTER (
            WHERE delay_days > 0
              AND has_review
        ) AS late_reviewed_orders,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE delay_days > 0
                  AND has_review
                  AND review_score <= 2
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE delay_days > 0
                      AND has_review
                ), 0
            ), 2
        ) AS late_low_rating_pct,
        ROUND(
            SUM(merchandise_value) FILTER (
                WHERE delay_days > 0
            ), 2
        ) AS late_order_merchandise_value
    FROM scopes
    GROUP BY
        section_order,
        section,
        dimension
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY section_order
            ORDER BY valid_orders DESC, dimension
        ) AS regional_rank
    FROM metrics
)
SELECT
    section,
    dimension,
    valid_orders,
    reviewed_orders,
    avg_review_score,
    low_rating_pct,
    late_reviewed_orders,
    late_low_rating_pct,
    late_order_merchandise_value
FROM ranked
WHERE section_order <> 3
   OR regional_rank <= 10
ORDER BY
    section_order,
    CASE
        WHEN section_order = 2 THEN
            CASE dimension
                WHEN 'On-time / Early' THEN 1
                WHEN 'Late 1-3 Days' THEN 2
                WHEN 'Late 4-7 Days' THEN 3
                ELSE 4
            END
        ELSE regional_rank
    END;






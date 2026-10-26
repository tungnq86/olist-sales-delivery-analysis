# KPI Dictionary

**Project:** E-commerce Sales & Delivery Analysis  
**Data:** Olist e-commerce orders, Brazil | January 2017–August 2018  
**Tools:** PostgreSQL, DBeaver and Power BI

This document defines the main metrics used across the three dashboard pages. Values refer to the **All Years** view, with orders selected by `order_purchase_timestamp` from `2017-01-01` (inclusive) to `2018-09-01` (exclusive). See the [Validation Summary](validation_summary.md) for the SQL checks.

## Measurement rules

- **Order counts** use distinct `order_id` where an order has multiple items. **Merchandise value** is the sum of `order_items.price`, excluding freight.
- **Valid delivery** means `order_status = 'delivered'`, both actual and estimated delivery dates are available, and actual delivery is not earlier than purchase.
- **Delivery delay** compares actual and estimated **calendar dates**: `actual_date - estimated_date`. `<= 0` is on time/early; `> 0` is late. **Delivery duration** instead measures elapsed days from purchase to delivery.
- **Low rating** means a review score of **1 or 2**. Review-based rates exclude orders without reviews. SQL reconciliation uses one latest-review record per order (`order_reviews_latest`).
- Regions are based on **customer state**. All percentages have the relevant filtered population as their denominator; differences between percentages use **percentage points (pp)**.

## 1. Sales Performance

| Metric | Definition / calculation | All Years | SQL check |
|---|---|---:|---|
| **Total Orders** | Distinct delivered orders appearing in `order_items` | **96,211** | 09.1, 09.3 |
| **Merchandise Sales** | `SUM(order_items.price)` for delivered orders; excludes freight | **R$13,181,027.13** | 09.3–09.4 |
| **Average Order Value** | Merchandise Sales / Total Orders | **R$137.00** | 09.3 |
| **SP Sales Share** | SP Merchandise Sales / total Merchandise Sales | **38.36%** | 09.4 |

The monthly sales chart groups orders by **purchase month**; the category and state charts rank merchandise sales, not order counts. In SQL 09.4, `health_beauty` leads product categories (**R$1.23M**) and SP leads states (**R$5.06M**).

**Scope note:** “Total Orders” on this page means *delivered orders with items*, not all orders placed. Merchandise Sales is not net revenue or profit.

## 2. Delivery Performance

| Metric | Definition / calculation | All Years | SQL check |
|---|---|---:|---|
| **Valid Delivered Orders** | Delivered orders meeting the date-quality checks above | **96,203** | 09.1–09.2, 09.5 |
| **Late Delivery Orders** | Valid orders with delay `> 0` days | **6,531** | 09.5 |
| **On-time Delivery Rate** | Valid orders with delay `<= 0` / all valid orders | **93.21%** | 09.5 |
| **Average Delivery Days** | Average elapsed `(delivery timestamp - purchase timestamp)` in days | **12.54** | 09.5 |
| **Late 1–3 Days** | Late orders delayed 1–3 calendar days | **1,869 (28.62%)** | 09.5 |
| **Late 4–7 Days** | Late orders delayed 4–7 calendar days | **1,802 (27.59%)** | 09.5 |
| **Late 8+ Days** | Late orders delayed at least 8 calendar days | **2,860 (43.79%)** | 09.5 |

Severity percentages use **6,531 late orders** as their denominator. Monthly reliability is grouped by **purchase month**. For the regional Top 10 (ranked by valid order volume), BA had the highest late-delivery rate (**12.17%**); SP had the largest late-order count (**1,817**). These represent different operational concerns.

**Calculation note:** SQL returned **12.54** days using exact timestamps, versus **12.48** using calendar-date subtraction. The displayed Power BI KPI matches the timestamp calculation; its full DAX measure has not been separately reviewed.

## 3. Customer Impact

| Metric | Definition / calculation | All Years | SQL check |
|---|---|---:|---|
| **Reviewed Delivered Orders** | Distinct delivered orders with a nonblank delivery delay and a matching review | **95,560** | 09.1, 09.6 |
| **Average Review Score** | Average `review_score` among reviewed delivered orders | **4.16 / 5** | 09.6 |
| **Late Reviewed Orders** | Reviewed delivered orders with delay `> 0` | **6,378** | 09.6 |
| **Late Low Rating Rate** | Late reviewed orders with score `<= 2` / all late reviewed orders | **62.42%** | 09.6 |
| **Late-order Merchandise Value** | Merchandise value of **all valid late-delivered orders**, with or without reviews | **R$985,618.47** | 09.6 |
| **Overall Low Rating Rate** | Reviewed orders rated 1–2 / all reviewed orders | **12.80%** | 09.6 |

**Customer review by delivery delay** (denominators include only reviewed orders):

| Delivery timing | Reviewed orders | Low rating rate | Avg review score |
|---|---:|---:|---:|
| On time / early | 89,182 | 9.25% | 4.29 |
| Late 1–3 days | 1,851 | 32.14% | 3.29 |
| Late 4–7 days | 1,748 | 67.68% | 2.10 |
| Late 8+ days | 2,779 | 79.27% | 1.70 |

- **Review Score Drop:** difference between average scores for on-time/early and late 8+ days, displayed as **2.59 points**.
- **Low Rating Gap:** Difference between the low-rating rates for late 8+ day and on-time/early reviewed orders. Validated using unrounded SQL rates (79.2731% vs. 9.2474%), confirming the **+70.03 percentage-point** gap displayed in Power BI.
- **Regional Exposure Watchlist:** Top 5 states by late-order merchandise value: **SP, RJ, MG, BA, RS**. SP leads exposure (**R$269.1K**). RJ has the largest exposure among states whose late low-rating rate exceeds the overall **62.42%** benchmark (**R$215.4K; 73.08%**). The regional scatterplot uses late-order value (X), late low-rating rate (Y) and late reviewed order count (bubble size).

**Interpretation note:** Late-order merchandise value is **not lost revenue**. The association between delays and ratings does **not** establish causation.

## Population differences and technical notes

| Population | Orders | Why it differs |
|---|---:|---|
| Sales: delivered with items | **96,211** | Includes 8 delivered orders with missing actual delivery dates |
| Delivery: valid delivered | **96,203** | Excludes those 8 orders |
| Customer: reviewed delivered | **95,560** | Excludes another 643 orders without matching reviews in the latest-review view |

The `Reviewed Delivered Orders` DAX checks for a nonblank delivery delay but does not separately test whether delivery followed purchase; the SQL set comparison found no exception within this reporting period.

**Measure provenance:** Actual DAX was reviewed for `Total Orders`, `Merchandise Sales`, `Average Order Value`, `Valid Delivered Orders`, `Reviewed Delivered Orders`, and the `Delivery Delay Days` calculated column. Other definitions above are **SQL-validated calculation equivalents**, not claims that every underlying DAX formula was inspected. In particular, `Reviewed Delivered Orders` has an explicit Jan 2017–Aug 2018 date restriction in DAX; revisit it if the reporting window changes.

**References:** [`validation_summary.md`](validation_summary.md) · `sql/09_kpi_reconciliation.sql` (sections 09.1–09.6) · Power BI dashboard

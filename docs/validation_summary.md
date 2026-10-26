# Data Validation Summary

**Project:** E-commerce Sales & Delivery Analysis  
**Data:** Olist e-commerce orders, Brazil | January 2017–August 2018  
**Environment:** PostgreSQL (`olist_ecom`, `public`) and Power BI

I used SQL to cross-check the main dashboard metrics and investigate differences between the Sales, Delivery and Customer datasets. Results below are based on SQL outputs and Power BI figures reviewed during project development.

## 1. Validation approach

- Apply the same **purchase-date window** in SQL: `>= 2017-01-01` and `< 2018-09-01`.
- Reproduce each KPI's status, delivery-date and review filters rather than treating all order counts as identical.
- Use `COUNT(DISTINCT order_id)` for orders and sum item prices at **order level before joining reviews**, avoiding inflated totals.
- Use `public.order_reviews_latest` for one review record per order in SQL.
- Compare headline values numerically; check selected monthly, category and regional visuals against their SQL breakdowns.

## 2. Checks completed

| SQL section | Area | Result |
|---|---|---|
| **09.1–09.2** | Order counts and missing delivery dates | Counts matched; 8 missing actual dates identified |
| **09.3** | Sales KPIs | Orders, Merchandise Sales and AOV matched |
| **09.4** | Sales by month, category and state | Main totals and SP share matched; visual rankings/trends consistent |
| **09.5** | Delivery KPIs, severity and states | Main KPIs, delay buckets and key regional indicators matched |
| **09.6** | Reviews, delay buckets and exposure | Main KPIs, reviewed populations and key regional values matched |

Here, **matched** means SQL agreed with the Power BI *displayed value* at its available precision. **Visually consistent** means a trend or ranking was compared with the report, not every plotted point exported and tested automatically.

## 3. Order populations and data quality

| Population | SQL / Power BI | Difference |
|---|---:|---|
| Delivered orders with items | **96,211** | Sales population |
| Valid delivered orders | **96,203** | **8** excluded: missing actual delivery date |
| Reviewed delivered orders | **95,560** | Another **643** lack a matching latest review |

The population comparison also returned **0** delivery-valid orders outside the Sales population and **0** reviewed orders outside the Delivery-valid population **for this reporting window**. The eight excluded orders had estimated dates but no actual delivery timestamp. Missing delivery dates were not imputed.

The **643** delivery-valid orders without a matching review split into **490** on-time/early and **153** late orders. They are excluded from review-rate denominators, not from delivery KPIs. This describes **review coverage in the available data**, not why customers did or did not provide feedback.

## 4. Results by dashboard page

### Sales Performance

| Check | SQL result | Comparison |
|---|---:|---|
| Delivered orders with items | **96,211** | Matched |
| Merchandise Sales (excl. freight) | **R$13,181,027.13** | Power BI: R$13.18M |
| Average Order Value | **R$137.00** | Matched |
| SP merchandise sales / share | **R$5,055,587.13 / 38.36%** | Matched dynamic insight |

SQL 09.4 returned **20 purchase months** (Jan 2017–Aug 2018). **November 2017** was the highest sales month (**R$987,765.37**). `health_beauty` led product categories (**R$1.23M**), followed by `watches_gifts` (**R$1.16M**). The chart trend and Top 10 state/category rankings were visually consistent with SQL.

### Delivery Performance

| Check | SQL result | Comparison |
|---|---:|---|
| Valid Delivered Orders | **96,203** | Matched |
| Late Delivery Orders | **6,531** | Matched |
| On-time Delivery Rate | **93.21%** | Matched |
| Average Delivery Days (exact timestamps) | **12.54** | Matched displayed value |
| Late 1–3 / 4–7 / 8+ days | **1,869 / 1,802 / 2,860** | Bucket counts matched |
| Severity share | **28.62% / 27.59% / 43.79%** | Matched |

The timestamp-based delivery average was **12.54** days; a calendar-date calculation gave **12.48** days, so the method matters. The lowest on-time month shown in the SQL batch was **March 2018 (81.04%)**. In the Top 10 states by valid order volume, **BA** had the highest late-delivery rate (**12.17%**). **SP** had **1,817** late deliveries, the largest count.

### Customer Impact

| Check | SQL result | Comparison |
|---|---:|---|
| Reviewed Delivered Orders | **95,560** | Matched |
| Average Review Score | **4.16 / 5** | Matched |
| Late Low Rating Rate | **62.42%** | Matched |
| Late-order Merchandise Value | **R$985,618.47** | Power BI: R$985.62K |

**By delay bucket (reviewed orders only):**

| Bucket | Reviewed orders | Low-rating rate |
|---|---:|---:|
| On time / early | 89,182 | **9.25%** |
| Late 1–3 days | 1,851 | **32.14%** |
| Late 4–7 days | 1,748 | **67.68%** |
| Late 8+ days | 2,779 | **79.27%** |

The regional exposure watchlist was consistent with SQL: **SP (R$269,077.55; 54.35% late low rating)** and **RJ (R$215,415.46; 73.08%)** were the two highest-value states. RJ exceeded the overall late low-rating benchmark of **62.42%**; SP did not.

## 5. Remaining checks and interpretation limits

- **Low Rating Gap:** Validated against unrounded SQL rates. The low-rating rate was 9.2474% for on-time/early deliveries and 79.2731% for deliveries delayed by 8+ days, confirming a gap of **70.03 percentage points**.
- **DAX and review lineage:** Exact DAX was reviewed for six core expressions, but not every dashboard measure. Before describing the model as fully audited, confirm that Power BI's `OrderReviews` table uses the same deduplicated review logic as `order_reviews_latest`.
- **Visual coverage:** Key totals, rankings and representative values were checked; a full row-by-row export comparison of every Power BI visual was not performed. Year-slicer and page interactions were also tested manually, not through automated regression tests.
- **Interpretation:** Review-based results exclude orders without reviews. Late-order merchandise value is **not lost revenue**, and the relationship between delays and low ratings is **associative, not causal**.

**Outcome:** The main SQL and Power BI results reconcile under the tested filters. These checks support the dashboard's reported figures without implying that every DAX expression or visual interaction has been independently audited.

**References:** [`kpi_dictionary.md`](kpi_dictionary.md) · [`business_findings_recommendations.md`](business_findings_recommendations.md) · `sql/09_kpi_reconciliation.sql` (sections 09.1–09.6)

# E-commerce Sales, Delivery & Customer Impact

**SQL (PostgreSQL) | Power BI | Data Validation**  
**Dataset:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)  
**Analysis period:** January 2017–August 2018, based on order purchase date

## Overview

This project brings together sales, delivery and customer review data to explore e-commerce performance beyond headline metrics. It looks at where merchandise sales are concentrated, how delivery delays differ across time and regions, and how those delays relate to customer feedback.

The analysis was carried out in PostgreSQL, with the results presented in a three-page Power BI report.

## Questions explored

- Which product categories and customer states contribute most to merchandise sales?
- How much do overall delivery rates tell us about severe delays and regional performance?
- How do customer reviews differ by delivery delay, and which regions warrant a closer look?

## Tools & approach

**PostgreSQL + DBeaver — Data exploration and SQL analysis**  
Joined order, item, customer, product and review data; checked delivery dates and order populations; used an order-level latest-review view to avoid duplicate review counts in SQL. Queries cover sales trends, delivery reliability, delay severity and regional comparisons.

**Power BI — Data modelling and reporting**  
Built a three-page report with DAX measures, monthly trends, category and state comparisons, delivery-delay buckets and interactive year filtering.

**SQL–Power BI reconciliation — Quality checks**  
Recalculated key report metrics using SQL and checked the effects of filtering, joining item-level data and selecting reviewed orders. The results are documented separately rather than treating every dashboard value as automatically verified.

## Power BI report

| Page | Main analysis |
|---|---|
| **Sales Performance** | Merchandise sales, average order value, monthly trends, top categories and states |
| **Delivery Performance** | On-time rate, average delivery time, delay severity, monthly changes and regional diagnostics |
| **Customer Impact** | Review scores, low-rating rates by delay bucket and regional late-order merchandise value |

### Dashboard preview

The report has three connected pages. Screenshots below show the **Year = All** view; select an image to see it at full resolution.

**Sales Performance**  
[![Sales Performance dashboard](images/01_sales_performance.png)](images/01_sales_performance.png)

**Delivery Performance**  
[![Delivery Performance dashboard](images/02_delivery_performance.png)](images/02_delivery_performance.png)

**Customer Impact**  
[![Customer Impact dashboard](images/03_customer_impact.png)](images/03_customer_impact.png)

## Selected findings

- **R$13.18M** in merchandise sales from delivered orders (excluding freight); **São Paulo (SP)** contributed **38.36%**.
- **93.21%** of valid delivered orders arrived on time or early, but **43.79% of late deliveries** were at least eight days late.
- Low ratings (1–2 stars) appeared in **9.25%** of reviewed on-time/early orders, compared with **79.27%** of reviewed orders delayed by eight or more days.
- **SP** had the highest merchandise value associated with late orders (**R$269.1K**). **Rio de Janeiro (RJ)** combined substantial late-order value (**R$215.4K**) with a **73.08%** low-rating rate among late reviewed orders.

These results point to different priorities: severe delays overall, late-order volume in SP, delivery reliability in Bahia (BA), and customer experience in RJ. Details are in [Business Findings & Recommendations](docs/business_findings_recommendations.md).

## Data checks & KPI scope

The main order populations reconcile between SQL and the Power BI report:

| Population | Orders |
|---|---:|
| Delivered orders with items (sales) | **96,211** |
| Valid delivered orders with usable delivery dates | **96,203** |
| Valid delivered orders with a matching review | **95,560** |

The differences come from **8** orders missing actual delivery timestamps and **643** valid deliveries without a matching review in the deduplicated SQL view. This matters because sales, delivery and review metrics do not share exactly the same denominator.

See the [KPI Dictionary](docs/kpi_dictionary.md) for metric definitions and the [Validation Summary](docs/validation_summary.md) for SQL reconciliation results and remaining checks.

## Repository structure

```text
olist-sales-delivery-analysis/
├── README.md
├── sql/                       # SQL scripts 01–09, including KPI reconciliation
├── powerbi/                   # Power BI report (.pbix)
├── images/                    # Dashboard screenshots
└── docs/
    ├── kpi_dictionary.md
    ├── validation_summary.md
    └── business_findings_recommendations.md
```

## Scope & limitations

The dataset is historical, and 2018 covers January–August only. Review-based measures exclude orders without matching reviews. **Late-order merchandise value is not lost revenue**, and the observed relationship between delivery delays and ratings does not establish causation.

**Source:** Olist's public Brazilian e-commerce dataset on Kaggle. Raw data files are not included in this repository.

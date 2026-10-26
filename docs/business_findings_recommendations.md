# Business Findings & Recommendations

**Project:** E-commerce Sales & Delivery Analysis  
**Data:** Olist e-commerce orders, Brazil | January 2017–August 2018

## Overview

This project examines how sales performance, delivery reliability and customer feedback relate to each other. While the overall on-time delivery rate was relatively strong, severe delays and regional differences reveal areas worth looking into more closely.

## Key findings

### 1. Sales are concentrated in São Paulo

Delivered orders generated **R$13.18M** in merchandise sales, excluding freight. **São Paulo (SP) accounted for 38.36%** of the total, while `health_beauty` was the top product category (**R$1.23M**).

Given its sales contribution, SP is an important market to consider when examining delivery performance and customer experience.

### 2. A strong on-time rate does not tell the whole delivery story

Of **96,203** valid delivered orders, **93.21%** arrived on time or early. However, **6,531** orders were late, and **2,860** of those (**43.79%**) were delayed by at least eight days. The on-time rate also dropped to **81.04%** for orders purchased in March 2018.

This suggests that both delay severity and changes over time deserve attention alongside the overall delivery rate.

### 3. Regional delivery issues look different depending on the metric

**SP had the highest number of late deliveries (1,817)** despite a **95.50%** on-time rate. **Bahia (BA)** recorded a **12.17%** late-delivery rate, the highest among the ten states with the most valid delivered orders.

SP stands out for delay volume, while BA stands out for its delay rate. Both measures are useful, but they point to different questions.

### 4. Longer delays are linked to poorer customer reviews

Among reviewed orders, **9.25%** of on-time or early deliveries received a low rating (1–2 stars), compared with **79.27%** of orders delayed by eight or more days. Average review scores were **4.29** and **1.70**, respectively.

The difference is substantial and worth investigating. It shows an association, not proof that delivery delays caused the ratings.

### 5. Rio de Janeiro deserves attention when order value and reviews are viewed together

Late deliveries were associated with **R$985.62K** in merchandise value overall. **SP** had the highest amount (**R$269.1K**), while **Rio de Janeiro (RJ)** followed with **R$215.4K**. Among late reviewed orders, RJ had a notably higher low-rating rate (**73.08%**) than SP (**54.35%**) and the overall benchmark (**62.42%**).

SP has greater commercial exposure by value, while RJ stands out when that value is considered alongside customer dissatisfaction.

## Recommended next steps

Based on these findings, I would prioritise the following areas for further investigation:

| Priority | Focus | Suggested action | Metrics to track |
|---|---|---|---|
| **1** | **Severe delays** | Break down 8+ day delays by state and purchase month to find recurring patterns. Explore earlier alerts or customer updates for orders at risk. | 8+ day delay rate; late low-rating rate |
| **2** | **RJ customer experience** | Review delivery exceptions and low-rated orders in RJ, then test whether more proactive communication improves the experience. | RJ on-time rate; low-rating rate among late reviewed orders |
| **3** | **SP and BA operations** | Investigate SP's high volume of late orders and BA's high late-delivery rate separately, rather than applying the same response to both. | SP late-order count; BA late-delivery rate |

*Notes:* The dataset is historical and 2018 covers January–August only. Review-based metrics exclude orders without reviews. **Late-order merchandise value is not lost revenue.** The analysis does not establish causes, and the recommendations have not been tested. Detailed KPI definitions and SQL checks are available in the [KPI Dictionary](kpi_dictionary.md) and [Validation Summary](validation_summary.md).

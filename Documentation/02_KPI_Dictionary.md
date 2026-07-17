# KPI Dictionary — 35 Growth & Product Metrics
### Netflix Growth & User Engagement Analytics Platform

Each KPI includes its formula, business meaning, and which team primarily owns it.

## A. Acquisition & Growth
| # | KPI | Formula | Why It Matters |
|---|-----|---------|-----------------|
| 1 | **New Signups** | COUNT(distinct users by signup_date) | Top-of-funnel growth volume |
| 2 | **Signup Growth Rate %** | (This month signups − Last month) / Last month | Momentum of top-of-funnel |
| 3 | **CAC (Customer Acquisition Cost)** | Total marketing spend / New paying customers | Efficiency of growth spend |
| 4 | **Organic Acquisition %** | Organic signups / Total signups | Reliance on paid vs. free growth |
| 5 | **Paid Acquisition %** | Paid-channel signups / Total signups | Inverse of organic; cost exposure |
| 6 | **Conversion Rate (Signup → Paid)** | Paying users / Total signups | Funnel health from free to paid |
| 7 | **Premium Conversion Rate** | Premium plan subs / Total active subs | Upsell/monetization strength |
| 8 | **Referral Rate** | Users acquired via referral / Total users | Low-cost, high-trust growth channel |
| 9 | **Campaign ROI** | (Attributed revenue − Spend) / Spend | Marketing spend effectiveness |
| 10 | **Click-Through Rate (CTR)** | Clicks / Impressions | Ad creative & targeting quality |

## B. Engagement
| # | KPI | Formula | Why It Matters |
|---|-----|---------|-----------------|
| 11 | **DAU (Daily Active Users)** | Distinct users with a session on a given day | Daily habit strength |
| 12 | **WAU (Weekly Active Users)** | Distinct users active in trailing 7 days | Weekly engagement footprint |
| 13 | **MAU (Monthly Active Users)** | Distinct users active in trailing 30 days | Overall active base size |
| 14 | **Stickiness (DAU/MAU)** | DAU ÷ MAU | How habitual the product is (higher = stickier) |
| 15 | **Average Session Duration** | Total session minutes / Total sessions | Depth of a single visit |
| 16 | **Average Episodes per Session** | Episodes watched / Sessions (series only) | Binge behavior intensity |
| 17 | **Binge Rate %** | Sessions with 3+ episodes of same title / Total series sessions | Strength of content hook |
| 18 | **Completion Rate %** | Avg(watch duration / content duration) | Whether content satisfies once started |
| 19 | **Watch Time (Total)** | SUM(watch_duration_minutes) | Core engagement volume metric |
| 20 | **Content Engagement Score** | Views × Completion% × Avg Rating (composite) | Ranks titles by holistic engagement, not just views |
| 21 | **Genre Popularity** | Views per genre (or per genre per country) | Guides content acquisition/production |
| 22 | **Search-to-Watch Conversion %** | Searches leading to a watch within 24h / Total clicked searches | Discovery/search effectiveness |
| 23 | **Active Users (by segment)** | Users meeting a defined activity threshold | Tracks engaged base size over time |
| 24 | **Dormant Users** | Users with no activity in last 60 days | Early warning for churn risk pool |

## C. Retention & Churn
| # | KPI | Formula | Why It Matters |
|---|-----|---------|-----------------|
| 25 | **Monthly Churn Rate %** | Cancellations in month / Active subscribers at start of month | Core retention health metric |
| 26 | **Retention Rate %** | 1 − Monthly Churn Rate | Inverse framing of churn for exec reporting |
| 27 | **Day-30 Retention** | Users still active 30 days post-signup / Cohort size | Early-lifecycle stickiness |
| 28 | **Cohort Retention Curve** | % of cohort active at month 0,1,2...N | Shows where the drop-off cliff occurs |
| 29 | **Cancellation Rate by Reason** | Count per cancellation_reason / Total cancellations | Diagnoses root cause of churn |
| 30 | **Reactivation Rate %** | Users who resubscribed after cancelling / Total who ever cancelled | Win-back program effectiveness |
| 31 | **Customer Lifetime (Avg Tenure)** | Avg(end_date − start_date) across subscriptions | Expected relationship length |

## D. Revenue & Monetization
| # | KPI | Formula | Why It Matters |
|---|-----|---------|-----------------|
| 32 | **MRR (Monthly Recurring Revenue)** | SUM(successful payments in month) | Primary revenue health metric |
| 33 | **ARR (Annual Recurring Revenue)** | MRR × 12 | Annualized run-rate for planning |
| 34 | **ARPU (Average Revenue Per User)** | MRR / Active subscribers | Monetization efficiency per user |
| 35 | **LTV (Customer Lifetime Value)** | Total revenue per user across their tenure (or ARPU × avg lifetime) | Ceiling for sustainable CAC; pairs with LTV:CAC ratio |

> **LTV:CAC ratio** (derived from #3 and #35) is the single most important
> combined metric for a Growth team — a healthy SaaS/subscription business
> targets 3:1 or higher.

### A note on churn measurement
This project's SQL/Python layer illustrates two related-but-different views of churn:
1. **Monthly Churn Rate** (KPI #25) — the correct, industry-standard, point-in-time metric.
2. A **cumulative lifetime cancellation rate** (used in a few exploratory SQL/Python queries)
   — the % of *all* historical subscription records that ended in cancellation. This number
   is naturally much higher because it includes subscriptions from early cohorts that have
   had years to lapse. It's useful for lifetime-value modeling but should never be reported
   to executives as "current churn" — that's always the monthly metric.

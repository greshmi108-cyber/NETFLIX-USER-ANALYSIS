# Power BI Dashboard Design Guide
### Netflix Growth & User Engagement Analytics Platform

> **Note on scope:** Power BI Desktop (.pbix) is a binary format that must be built
> interactively in the Power BI application — it can't be generated as a text file.
> This guide gives you everything needed to build it in ~2-3 hours: the data model,
> every DAX measure, and the exact page-by-page layout. Load the CSVs from `/Dataset`
> into Power BI, paste in the measures below, and follow the layout spec per page.

---

## 1. Data Model (Star Schema)

Import all 11 CSVs from `/Dataset`. Build these relationships (all 1-to-many, single direction unless noted):

```
users (1) ──< subscriptions (1) ──< payments
users (1) ──< sessions (1) ──< watch_history
users (1) ──< devices
users (1) ──< ratings
users (1) ──< search_history
users (1) ──< marketing_campaigns   (via campaign_id)
content_library (1) ──< episodes
content_library (1) ──< watch_history
content_library (1) ──< ratings
episodes (1) ──< watch_history
devices (1) ──< sessions
devices (1) ──< watch_history
```

Also create a **Date dimension table** (calendar table, Jan 2022–Dec 2026) and mark it as
a Date Table. Relate it to `signup_date`, `payment_date`, `watch_date`, and `session_start`
using **inactive relationships**, activated per-visual with `USERELATIONSHIP()` where needed
(a single active relationship to `watch_date` is usually the default).

---

## 2. Core DAX Measures (paste into a dedicated "_Measures" table)

### Acquisition & Growth
```dax
Total Users = DISTINCTCOUNT(users[user_id])

New Signups = CALCULATE(DISTINCTCOUNT(users[user_id]), 
                REMOVEFILTERS(), VALUES(DateTable[Date]))

Signup Growth % = 
VAR CurrM = [New Signups]
VAR PrevM = CALCULATE([New Signups], DATEADD(DateTable[Date], -1, MONTH))
RETURN DIVIDE(CurrM - PrevM, PrevM)

CAC (Blended) = DIVIDE(SUM(marketing_campaigns[spend_usd]), SUM(marketing_campaigns[signups_attributed]))

Organic Acquisition % = 
DIVIDE(
  CALCULATE(DISTINCTCOUNT(users[user_id]), users[acquisition_channel] = "Organic"),
  [Total Users])

Paid Acquisition % = 1 - [Organic Acquisition %]

Campaign ROI = DIVIDE(SUM(marketing_campaigns[signups_attributed]) * [ARPU], SUM(marketing_campaigns[spend_usd])) - 1
```

### Engagement
```dax
DAU = DISTINCTCOUNT(sessions[user_id])   -- filtered to a single day via Date slicer

WAU = CALCULATE(DISTINCTCOUNT(sessions[user_id]), DATESINPERIOD(DateTable[Date], MAX(DateTable[Date]), -7, DAY))

MAU = CALCULATE(DISTINCTCOUNT(sessions[user_id]), DATESINPERIOD(DateTable[Date], MAX(DateTable[Date]), -30, DAY))

Stickiness (DAU/MAU) = DIVIDE([DAU], [MAU])

Avg Session Duration (min) = AVERAGE(sessions[session_duration_minutes])

Avg Watch Time per User (min) = DIVIDE(SUM(watch_history[watch_duration_minutes]), DISTINCTCOUNT(watch_history[user_id]))

Completion Rate % = AVERAGE(watch_history[completion_pct])

Avg Titles per Session = DIVIDE(COUNTROWS(watch_history), DISTINCTCOUNT(watch_history[session_id]))

Binge Sessions = 
CALCULATE(
  COUNTROWS(
    FILTER(
      SUMMARIZE(watch_history, watch_history[session_id], watch_history[content_id], "EpCount", COUNTROWS(watch_history)),
      [EpCount] >= 3
    )
  )
)

Binge Rate % = DIVIDE([Binge Sessions], DISTINCTCOUNT(watch_history[session_id]))
```

### Retention & Churn
```dax
Active Subscribers = CALCULATE(DISTINCTCOUNT(subscriptions[user_id]), subscriptions[status] = "Active")

Churned Subscribers = CALCULATE(DISTINCTCOUNT(subscriptions[user_id]), subscriptions[status] = "Cancelled")

Monthly Churn Rate % = 
VAR ActiveStartOfMonth = CALCULATE([Active Subscribers], DATEADD(DateTable[Date], -1, MONTH))
VAR CancelledThisMonth = CALCULATE(DISTINCTCOUNT(subscriptions[user_id]),
                            subscriptions[status]="Cancelled",
                            DATESINPERIOD(DateTable[Date], MAX(DateTable[Date]), -1, MONTH))
RETURN DIVIDE(CancelledThisMonth, ActiveStartOfMonth)

Retention Rate % = 1 - [Monthly Churn Rate %]

Reactivation Rate % = 
VAR Cancelled = CALCULATE(DISTINCTCOUNT(subscriptions[user_id]), subscriptions[status]="Cancelled")
VAR Reactivated = CALCULATE(DISTINCTCOUNT(subscriptions[user_id]),
                    FILTER(subscriptions, subscriptions[status]="Active"),
                    USERELATIONSHIP(subscriptions[user_id], subscriptions[user_id]))
RETURN DIVIDE(Reactivated, Cancelled)

Dormant Users = 
CALCULATE(
  DISTINCTCOUNT(users[user_id]),
  FILTER(users, CALCULATE(MAX(watch_history[watch_date])) < TODAY() - 60)
)
```

### Revenue & Monetization
```dax
MRR = CALCULATE(SUM(payments[amount_usd]), payments[status]="Success")

ARR = [MRR] * 12

ARPU = DIVIDE([MRR], [Active Subscribers])

LTV (Avg) = DIVIDE(
  CALCULATE(SUM(payments[amount_usd]), payments[status]="Success"),
  DISTINCTCOUNT(payments[user_id])
)

Premium Conversion Rate % = 
DIVIDE(
  CALCULATE(DISTINCTCOUNT(subscriptions[user_id]), subscriptions[plan_type]="Premium"),
  [Total Users])

Revenue Growth % = 
VAR CurrM = [MRR]
VAR PrevM = CALCULATE([MRR], DATEADD(DateTable[Date], -1, MONTH))
RETURN DIVIDE(CurrM - PrevM, PrevM)

Payment Failure Rate % = 
DIVIDE(
  CALCULATE(COUNTROWS(payments), payments[status]="Failed"),
  COUNTROWS(payments))
```

### Content & Segmentation
```dax
Content Engagement Score = 
[Avg Watch Time per User] * DIVIDE([Completion Rate %],100) * AVERAGE(ratings[rating])

Top Genre Rank = RANKX(ALL(content_library[genre]), CALCULATE(COUNTROWS(watch_history)))

Avg Rating = AVERAGE(ratings[rating])

Power User Count = 
CALCULATE(DISTINCTCOUNT(users[user_id]),
  FILTER(VALUES(users[user_id]), CALCULATE(DISTINCTCOUNT(sessions[session_id])) >= 20))
```

---

## 3. Dashboard Pages — Layout Specification

Each page below follows the same template: **KPI card row (top) → 2-3 visual row (middle)
→ slicers (left rail) → insight/recommendation text box (bottom)**. Use Netflix brand
colors: background `#141414`, accent `#E50914`, text `#FFFFFF`/`#B3B3B3`.

| # | Page | KPI Cards (top row) | Core Visuals | Filters (left rail) | Insight Box (bottom) |
|---|------|---------------------|---------------|----------------------|------------------------|
| 1 | **Executive Summary** | Total Users, MRR, ARR, Active Subscribers, Monthly Churn %, Stickiness | Revenue trend line, Subscriber growth line, Segment donut | Date range, Region | "MRR grew X% MoM; churn concentrated in Mobile plan" |
| 2 | **Growth Dashboard** | New Signups, Signup Growth %, CAC, Organic vs Paid % | Signup trend by channel (area), Funnel (Impression→Click→Signup→Paid) | Channel, Campaign, Date | Funnel drop-off point + fix recommendation |
| 3 | **User Acquisition** | Total Signups, CAC, Paid Acquisition %, Referral Rate | Signups by country (map), Signups by device, Channel table w/ conversion % | Country, Channel, Device | Best/worst performing channel by CAC |
| 4 | **Engagement Dashboard** | DAU, WAU, MAU, Stickiness, Avg Session Duration, Avg Titles/Session | DAU trend, Session duration by device (bar), Binge rate gauge | Device, Date, Plan | Device driving longest sessions |
| 5 | **Retention Dashboard** | Retention Rate, Day-30 Retention, Reactivation Rate, Dormant Users | Cohort retention heatmap (matrix), Retention curve line | Cohort month, Plan | Retention cliff month + intervention window |
| 6 | **Subscription Dashboard** | Active Subs, Plan Mix %, Premium Conversion %, Avg Tenure | Plan mix over time (stacked area), Upgrade/downgrade flow (Sankey) | Plan type, Billing cycle | Upsell opportunity segment |
| 7 | **Revenue Dashboard** | MRR, ARR, ARPU, LTV, Revenue Growth % | Revenue by plan (bar), Revenue by country (map), Payment method mix | Plan, Country, Payment method | Highest ARPU segment |
| 8 | **Content Analytics** | Total Titles, Avg Completion %, Avg Rating, Top Genre | Engagement score leaderboard (table), Genre popularity (bar), Completion by genre | Genre, Content type, Language | Underperforming genre for catalog investment |
| 9 | **Marketing Dashboard** | Total Spend, Total Impressions, CTR, Campaign ROI | ROI by campaign (bar, sorted), Spend vs Signups (scatter) | Channel, Region, Date | Top 3 campaigns to scale, bottom 3 to cut |
| 10 | **Churn Dashboard** | Monthly Churn %, Cancelled Subs, Payment Failure Rate | Churn by plan (bar), Cancellation reasons (horizontal bar), Churn trend line | Plan, Cancellation reason | Leading churn cause + fix |
| 11 | **Cohort Dashboard** | Cohort Count, Avg Month-1 Retention, Avg Month-3 Retention | Cohort retention matrix (full), Cohort size trend | Cohort month | Best-performing cohort and why |
| 12 | **User Segmentation** | Power Users, Regular Users, At-Risk Users, Dormant Users | Segment distribution (donut), Segment revenue contribution (bar), RFM scatter | Segment, Plan | Segment(s) to target for reactivation campaigns |

---

## 4. Slicers & Interactivity Standards
- Every page has: **Date range** (relative date slicer), **Region/Country**, **Plan Type**
- Cross-filtering enabled between all visuals on a page
- Drill-through set up from Executive Summary → each detail dashboard
- Tooltips enabled showing MoM % change on every KPI card
- Bookmarks for "Last 30 Days" / "Last 90 Days" / "YTD" quick views

## 5. Visual Design Standards
- Font: Segoe UI / Netflix Sans-style bold headers
- KPI cards use conditional formatting (green ▲ / red ▼ vs prior period)
- Consistent color coding: Acquisition = blue, Engagement = purple, Revenue = green, Churn = red
- Max 6 visuals per page to avoid clutter (executive-readable in under 30 seconds)

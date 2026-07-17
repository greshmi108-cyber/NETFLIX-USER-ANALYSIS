# Business Problem Statement
### Netflix Growth & User Engagement Analytics Platform

## Why Netflix Needs This

Netflix operates in a maturing, highly competitive streaming market (Disney+, Amazon
Prime Video, HBO Max, Hulu, regional players). Growth is no longer driven purely by
new-market expansion — it now depends on **extracting more value from the existing
subscriber base**: reducing churn, increasing engagement depth, improving monetization
per user, and making acquisition spend more efficient.

Leadership cannot make these decisions from gut feel. They need a single source of
truth that connects **acquisition → engagement → retention → revenue** into one
narrative, refreshed regularly, and broken down by the dimensions that matter
(plan type, geography, device, content genre, campaign).

Today, without this platform:
- Growth and Product teams work off fragmented spreadsheets and ad-hoc SQL pulls
- Churn is discovered a month after it happens, not predicted or intervened on
- Marketing can't tell which channels produce durable, high-LTV subscribers vs. cheap-but-churny ones
- Content decisions aren't tied back to retention or watch-time impact

## Business Objectives
1. Provide one governed view of subscriber growth, engagement, and revenue health
2. Identify at-risk segments before they churn, not after
3. Quantify which acquisition channels return the highest LTV:CAC, not just lowest CAC
4. Connect content investment to measurable engagement and retention outcomes
5. Give the Growth and Product orgs a shared KPI language and reporting cadence

## Growth Team Goals
- Increase free-trial → paid conversion rate
- Reduce blended CAC while improving LTV:CAC ratio
- Grow MRR/ARR through upsell (Basic → Standard → Premium) and reduced involuntary churn
- Improve referral and reactivation rates as low-cost growth levers

## Product Team Goals
- Increase DAU/MAU stickiness and average watch time per user
- Improve onboarding so new users reach an "aha moment" (first completed watch) faster
- Reduce time-to-churn by identifying disengagement signals early (recency, completion rate drop)
- Use content engagement scores to guide the recommendation engine and content investment

## Stakeholders
| Stakeholder | What they need from this platform |
|---|---|
| VP of Growth | Executive summary: MRR, churn, LTV:CAC, subscriber growth |
| Product Managers | Engagement funnels, feature/content usage, segmentation |
| Marketing/Performance Marketing | Campaign ROI, CAC by channel, funnel conversion |
| Content/Programming Team | Genre popularity, completion rates, content engagement scores |
| Finance/Revenue Operations | MRR, ARR, ARPU, payment failure/involuntary churn impact |
| Data/Analytics Engineering | Clean, documented, query-ready data model |

## Expected Outcomes
- A reusable, documented data model spanning 11 relational tables and 1M+ records
- 30+ SQL analyses answering real growth/product questions (retention, cohort, funnel, segmentation)
- A Python analysis layer producing cleaned data, engineered features, and reproducible charts
- A 12-page executive Power BI dashboard for daily/weekly decision-making
- 25 concrete, prioritized business recommendations Netflix leadership could act on this quarter

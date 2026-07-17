# 25 Interview Questions Based on This Project
### With guidance on what a strong answer covers

## Business & Strategy
1. **Why did you choose these specific KPIs for a streaming business?**
   *Cover: alignment with subscription-business economics (MRR/ARR/ARPU/LTV/CAC),
   engagement as a leading indicator of retention, churn as the lagging outcome.*
2. **How would you prioritize between improving acquisition vs. reducing churn?**
   *Cover: LTV:CAC framing — retention improvements compound, cheap acquisition with
   high churn destroys unit economics.*
3. **What's the difference between monthly churn rate and cumulative cancellation rate?**
   *Cover: point-in-time vs. all-time metric; why reporting the wrong one misleads execs.*
4. **How would you measure the ROI of a marketing campaign beyond just CAC?**
   *Cover: need LTV of acquired users, not just cost per signup — a channel can have
   low CAC but low-quality/high-churn users.*
5. **What would you tell the content team based on the Content Engagement Score?**
   *Cover: view count alone is a vanity metric; completion % and rating reveal true satisfaction.*

## SQL
6. **Walk me through your cohort retention query — why use a CTE here?**
7. **How does a window function like NTILE() help with RFM segmentation?**
8. **What's the difference between RANK(), DENSE_RANK(), and ROW_NUMBER(), and where did you use each?**
9. **How would you optimize a query joining a 350K-row watch_history table with users and content?**
   *Cover: indexing on join keys, filtering early, avoiding SELECT *, partitioning by date.*
10. **How did you calculate Day-30 retention, and why is that time window meaningful?**
11. **Explain your funnel query (impressions → clicks → signups → paid conversions). What are its limitations?**
    *Cover: attribution assumptions, last-touch vs multi-touch.*
12. **How would you detect and handle duplicate subscription records?**

## Python / Data Analysis
13. **How did you detect outliers in session duration, and why did you decide to keep them?**
    *Cover: IQR method; business judgment that long sessions are valid binge behavior, not noise.*
14. **What features did you engineer for the user-level model, and why?**
    *Cover: recency, tenure, engagement_score as composite — explain the weighting rationale.*
15. **What did the correlation analysis reveal about drivers of revenue?**
16. **How would you turn your rule-based segmentation (Power User/Regular/At-Risk) into
    a proper clustering model?**
    *Cover: K-means/hierarchical clustering on standardized engagement features, but note
    interpretability trade-off vs. business rules.*
17. **How would you validate that your synthetic dataset's churn/retention patterns are realistic?**
    *Cover: benchmarking against known SVOD industry ranges (~2-5% monthly churn, DAU/MAU stickiness ~15-25%).*

## Power BI / Dashboarding
18. **Why did you structure the data model as a star schema instead of one flat table?**
    *Cover: performance, avoiding fan-out/many-to-many issues, DAX filter propagation.*
19. **How do DAX measures like DATESINPERIOD() and DATEADD() help calculate MAU and MoM growth?**
20. **How would you design a dashboard so an executive gets the answer in under 30 seconds?**
    *Cover: KPI cards top-of-page, max 6 visuals, insight text box, consistent color coding.*
21. **What's the difference between a calculated column and a measure in Power BI, and when do you use each?**

## Behavioral / Project Ownership
22. **What was the hardest analytical decision you made in this project, and why?**
    *Good answer: the churn-metric ambiguity — choosing to clearly separate monthly
    vs. cumulative churn rather than let one mislead the reader.*
23. **If you had real Netflix data instead of synthetic data, what would you validate first?**
    *Cover: data quality/completeness checks, checking for survivorship bias, comparing
    to known public benchmarks.*
24. **How would this project change if the business asked you to focus specifically on
    reducing involuntary (payment-failure) churn?**
25. **How do you decide when a metric belongs on an executive dashboard vs. a deeper
    analyst-only report?**
    *Cover: actionability, refresh cadence, audience's decision rights.*

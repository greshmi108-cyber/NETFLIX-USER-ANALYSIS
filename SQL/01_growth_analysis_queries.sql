/* ============================================================================
   NETFLIX GROWTH & USER ENGAGEMENT ANALYTICS PLATFORM
   Advanced SQL Business Analysis — 32 Queries
   Author: Growth Analytics Team
   Dialect: PostgreSQL (window functions, CTEs — portable to Snowflake/BigQuery
            with minor date-function syntax changes)
   ============================================================================ */


/* ============================== SECTION A ==================================
   ACQUISITION & FUNNEL ANALYSIS
   ========================================================================= */

-- Q1. Monthly new signups trend
SELECT DATE_TRUNC('month', signup_date) AS signup_month,
       COUNT(*) AS new_users
FROM users
GROUP BY 1
ORDER BY 1;

-- Q2. Signup -> Paid conversion funnel by acquisition channel
WITH first_sub AS (
    SELECT u.user_id, u.acquisition_channel,
           MIN(s.start_date) AS first_sub_date
    FROM users u
    LEFT JOIN subscriptions s ON u.user_id = s.user_id
    GROUP BY u.user_id, u.acquisition_channel
)
SELECT acquisition_channel,
       COUNT(*) AS total_signups,
       COUNT(first_sub_date) AS converted_to_paid,
       ROUND(100.0 * COUNT(first_sub_date) / COUNT(*), 2) AS conversion_rate_pct
FROM first_sub
GROUP BY acquisition_channel
ORDER BY conversion_rate_pct DESC;

-- Q3. Campaign ROI ranking (Return on Ad Spend)
SELECT campaign_name, channel, spend_usd, signups_attributed,
       ROUND(spend_usd / NULLIF(signups_attributed, 0), 2) AS cac_per_signup,
       RANK() OVER (ORDER BY signups_attributed DESC) AS signup_rank
FROM marketing_campaigns
ORDER BY cac_per_signup ASC;

-- Q4. Free trial -> paid conversion rate
SELECT
    ROUND(100.0 * SUM(CASE WHEN status = 'Active' OR cancellation_reason IS NOT NULL
                            THEN 1 ELSE 0 END) FILTER (WHERE is_free_trial = TRUE)
          / NULLIF(COUNT(*) FILTER (WHERE is_free_trial = TRUE), 0), 2) AS trial_conversion_pct
FROM subscriptions;

-- Q5. Full acquisition funnel (Impression -> Click -> Signup -> Paid Sub)
WITH paid_users AS (
    SELECT DISTINCT user_id FROM subscriptions
)
SELECT
    SUM(mc.impressions) AS total_impressions,
    SUM(mc.clicks) AS total_clicks,
    SUM(mc.signups_attributed) AS total_signups,
    COUNT(DISTINCT pu.user_id) AS paid_conversions,
    ROUND(100.0 * SUM(mc.clicks) / NULLIF(SUM(mc.impressions), 0), 2) AS ctr_pct,
    ROUND(100.0 * SUM(mc.signups_attributed) / NULLIF(SUM(mc.clicks), 0), 2) AS click_to_signup_pct
FROM marketing_campaigns mc
LEFT JOIN users u ON u.campaign_id = mc.campaign_id
LEFT JOIN paid_users pu ON pu.user_id = u.user_id;


/* ============================== SECTION B ==================================
   RETENTION & COHORT ANALYSIS
   ========================================================================= */

-- Q6. Monthly cohort retention curve (classic cohort table using CTE + window fn)
WITH cohorts AS (
    SELECT user_id, DATE_TRUNC('month', signup_date) AS cohort_month
    FROM users
),
activity AS (
    SELECT DISTINCT user_id, DATE_TRUNC('month', watch_date) AS activity_month
    FROM watch_history
)
SELECT c.cohort_month,
       DATE_PART('year', a.activity_month) * 12 + DATE_PART('month', a.activity_month)
         - (DATE_PART('year', c.cohort_month) * 12 + DATE_PART('month', c.cohort_month)) AS month_number,
       COUNT(DISTINCT a.user_id) AS active_users
FROM cohorts c
JOIN activity a ON c.user_id = a.user_id AND a.activity_month >= c.cohort_month
GROUP BY 1, 2
ORDER BY 1, 2;

-- Q7. Cohort retention rate (% of cohort still active in month N vs month 0)
WITH cohorts AS (
    SELECT user_id, DATE_TRUNC('month', signup_date) AS cohort_month
    FROM users
),
activity AS (
    SELECT DISTINCT user_id, DATE_TRUNC('month', watch_date) AS activity_month
    FROM watch_history
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS total_users FROM cohorts GROUP BY 1
),
monthly_active AS (
    SELECT c.cohort_month,
           (DATE_PART('year', a.activity_month) * 12 + DATE_PART('month', a.activity_month))
           - (DATE_PART('year', c.cohort_month) * 12 + DATE_PART('month', c.cohort_month)) AS month_number,
           COUNT(DISTINCT a.user_id) AS active_users
    FROM cohorts c
    JOIN activity a ON c.user_id = a.user_id AND a.activity_month >= c.cohort_month
    GROUP BY 1, 2
)
SELECT ma.cohort_month, ma.month_number, ma.active_users, cs.total_users,
       ROUND(100.0 * ma.active_users / cs.total_users, 2) AS retention_pct
FROM monthly_active ma
JOIN cohort_size cs ON ma.cohort_month = cs.cohort_month
ORDER BY 1, 2;

-- Q8. Month-1 (30-day) retention rate per signup cohort
WITH first_month AS (
    SELECT u.user_id, DATE_TRUNC('month', u.signup_date) AS cohort_month
    FROM users u
),
retained AS (
    SELECT fm.cohort_month, fm.user_id,
           MAX(CASE WHEN w.watch_date BETWEEN u.signup_date + INTERVAL '30 day'
                                            AND u.signup_date + INTERVAL '60 day'
                    THEN 1 ELSE 0 END) AS retained_flag
    FROM first_month fm
    JOIN users u ON u.user_id = fm.user_id
    LEFT JOIN watch_history w ON w.user_id = fm.user_id
    GROUP BY fm.cohort_month, fm.user_id
)
SELECT cohort_month,
       COUNT(*) AS cohort_size,
       SUM(retained_flag) AS retained_users,
       ROUND(100.0 * SUM(retained_flag) / COUNT(*), 2) AS day30_retention_pct
FROM retained
GROUP BY cohort_month
ORDER BY cohort_month;

-- Q9. Churn rate by plan type (monthly)
SELECT plan_type,
       COUNT(*) AS total_subs,
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_subs,
       ROUND(100.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM subscriptions
GROUP BY plan_type
ORDER BY churn_rate_pct DESC;

-- Q10. Top 10 churn reasons ranked by frequency
SELECT cancellation_reason,
       COUNT(*) AS occurrences,
       RANK() OVER (ORDER BY COUNT(*) DESC) AS reason_rank
FROM subscriptions
WHERE status = 'Cancelled'
GROUP BY cancellation_reason
ORDER BY occurrences DESC
LIMIT 10;

-- Q11. Reactivation rate: users who cancelled and later resubscribed
WITH sub_counts AS (
    SELECT user_id, COUNT(*) AS n_subs,
           SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS n_cancelled
    FROM subscriptions
    GROUP BY user_id
)
SELECT
    COUNT(*) FILTER (WHERE n_cancelled >= 1) AS ever_cancelled_users,
    COUNT(*) FILTER (WHERE n_cancelled >= 1 AND n_subs > n_cancelled) AS reactivated_users,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_cancelled >= 1 AND n_subs > n_cancelled)
          / NULLIF(COUNT(*) FILTER (WHERE n_cancelled >= 1), 0), 2) AS reactivation_rate_pct
FROM sub_counts;

-- Q12. Dormant users (signed up but no watch activity in last 60 days)
SELECT COUNT(*) AS dormant_users
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM watch_history w
    WHERE w.user_id = u.user_id
      AND w.watch_date >= (SELECT MAX(watch_date) FROM watch_history) - INTERVAL '60 day'
);


/* ============================== SECTION C ==================================
   ENGAGEMENT ANALYSIS (DAU/WAU/MAU, Sessions, Watch Time)
   ========================================================================= */

-- Q13. DAU trend (last 90 days)
SELECT DATE(session_start) AS activity_date, COUNT(DISTINCT user_id) AS dau
FROM sessions
WHERE session_start >= (SELECT MAX(session_start) FROM sessions) - INTERVAL '90 day'
GROUP BY 1
ORDER BY 1;

-- Q14. WAU and MAU (rolling)
SELECT DATE_TRUNC('week', session_start) AS week_start, COUNT(DISTINCT user_id) AS wau
FROM sessions
GROUP BY 1
ORDER BY 1;

SELECT DATE_TRUNC('month', session_start) AS month_start, COUNT(DISTINCT user_id) AS mau
FROM sessions
GROUP BY 1
ORDER BY 1;

-- Q15. Stickiness ratio (DAU/MAU) by month
WITH dau AS (
    SELECT DATE_TRUNC('month', session_start) AS month_start,
           COUNT(DISTINCT user_id) * 1.0 / COUNT(DISTINCT DATE(session_start)) AS avg_dau
    FROM sessions GROUP BY 1
),
mau AS (
    SELECT DATE_TRUNC('month', session_start) AS month_start,
           COUNT(DISTINCT user_id) AS mau
    FROM sessions GROUP BY 1
)
SELECT d.month_start, d.avg_dau, m.mau,
       ROUND(100.0 * d.avg_dau / m.mau, 2) AS stickiness_pct
FROM dau d JOIN mau m ON d.month_start = m.month_start
ORDER BY 1;

-- Q16. Average session duration & episodes-per-session by device type
SELECT dv.device_type,
       ROUND(AVG(s.session_duration_minutes), 1) AS avg_session_minutes,
       COUNT(w.watch_id) * 1.0 / COUNT(DISTINCT s.session_id) AS avg_titles_per_session
FROM sessions s
JOIN devices dv ON s.device_id = dv.device_id
LEFT JOIN watch_history w ON w.session_id = s.session_id
GROUP BY dv.device_type
ORDER BY avg_session_minutes DESC;

-- Q17. Binge-watching rate (sessions with 3+ episodes of the same series)
WITH session_episode_counts AS (
    SELECT session_id, content_id, COUNT(*) AS episodes_watched
    FROM watch_history
    WHERE episode_id IS NOT NULL
    GROUP BY session_id, content_id
)
SELECT
    COUNT(*) FILTER (WHERE episodes_watched >= 3) AS binge_sessions,
    COUNT(*) AS total_series_sessions,
    ROUND(100.0 * COUNT(*) FILTER (WHERE episodes_watched >= 3) / COUNT(*), 2) AS binge_rate_pct
FROM session_episode_counts;

-- Q18. Completion rate by content genre
SELECT c.genre,
       ROUND(AVG(w.completion_pct), 1) AS avg_completion_pct,
       COUNT(*) AS total_views
FROM watch_history w
JOIN content_library c ON w.content_id = c.content_id
GROUP BY c.genre
ORDER BY avg_completion_pct DESC;

-- Q19. Content Engagement Score (composite: views x avg completion x avg rating)
WITH view_stats AS (
    SELECT content_id, COUNT(*) AS total_views, AVG(completion_pct) AS avg_completion
    FROM watch_history GROUP BY content_id
),
rating_stats AS (
    SELECT content_id, AVG(rating) AS avg_rating FROM ratings GROUP BY content_id
)
SELECT cl.title, cl.genre, vs.total_views, ROUND(vs.avg_completion, 1) AS avg_completion_pct,
       ROUND(COALESCE(rs.avg_rating, 0), 2) AS avg_rating,
       ROUND(vs.total_views * (vs.avg_completion / 100.0) * COALESCE(rs.avg_rating, 3), 1) AS engagement_score,
       RANK() OVER (ORDER BY vs.total_views * (vs.avg_completion / 100.0) * COALESCE(rs.avg_rating, 3) DESC) AS engagement_rank
FROM content_library cl
JOIN view_stats vs ON cl.content_id = vs.content_id
LEFT JOIN rating_stats rs ON cl.content_id = rs.content_id
ORDER BY engagement_score DESC
LIMIT 20;

-- Q20. Genre popularity by country (top genre per country using window function)
WITH genre_country AS (
    SELECT u.country, c.genre, COUNT(*) AS views,
           RANK() OVER (PARTITION BY u.country ORDER BY COUNT(*) DESC) AS rnk
    FROM watch_history w
    JOIN users u ON w.user_id = u.user_id
    JOIN content_library c ON w.content_id = c.content_id
    GROUP BY u.country, c.genre
)
SELECT country, genre AS top_genre, views
FROM genre_country
WHERE rnk = 1
ORDER BY views DESC;

-- Q21. Top 10 most-rewatched / most-engaged titles per month
SELECT DATE_TRUNC('month', watch_date) AS month, content_id,
       COUNT(*) AS views,
       DENSE_RANK() OVER (PARTITION BY DATE_TRUNC('month', watch_date) ORDER BY COUNT(*) DESC) AS monthly_rank
FROM watch_history
GROUP BY 1, 2
QUALIFY monthly_rank <= 10  -- Snowflake/BigQuery syntax; use subquery filter in PostgreSQL
ORDER BY 1, 3 DESC;

-- Q22. Average episodes watched per session (binge depth) using window functions
SELECT session_id, COUNT(*) AS episodes_in_session,
       AVG(COUNT(*)) OVER () AS avg_episodes_per_session_overall
FROM watch_history
WHERE episode_id IS NOT NULL
GROUP BY session_id;


/* ============================== SECTION D ==================================
   REVENUE, MONETIZATION & LTV
   ========================================================================= */

-- Q23. Monthly Recurring Revenue (MRR) trend
SELECT DATE_TRUNC('month', payment_date) AS revenue_month,
       SUM(amount_usd) AS total_revenue,
       COUNT(DISTINCT user_id) AS paying_users,
       ROUND(SUM(amount_usd) / NULLIF(COUNT(DISTINCT user_id), 0), 2) AS arpu
FROM payments
WHERE status = 'Success'
GROUP BY 1
ORDER BY 1;

-- Q24. Annual Recurring Revenue (ARR) estimate = latest MRR x 12
WITH latest_mrr AS (
    SELECT SUM(amount_usd) AS mrr
    FROM payments
    WHERE status = 'Success'
      AND DATE_TRUNC('month', payment_date) = (SELECT MAX(DATE_TRUNC('month', payment_date)) FROM payments)
)
SELECT mrr, mrr * 12 AS arr_estimate FROM latest_mrr;

-- Q25. Revenue by plan type & billing cycle
SELECT s.plan_type, s.billing_cycle,
       SUM(p.amount_usd) AS total_revenue,
       COUNT(DISTINCT p.user_id) AS subscribers
FROM payments p
JOIN subscriptions s ON p.subscription_id = s.subscription_id
WHERE p.status = 'Success'
GROUP BY s.plan_type, s.billing_cycle
ORDER BY total_revenue DESC;

-- Q26. Customer Lifetime Value (LTV) approximation per user
WITH user_revenue AS (
    SELECT user_id, SUM(amount_usd) AS total_paid,
           MIN(payment_date) AS first_payment, MAX(payment_date) AS last_payment
    FROM payments WHERE status = 'Success'
    GROUP BY user_id
)
SELECT user_id, total_paid,
       DATE_PART('day', last_payment - first_payment) / 30.0 AS tenure_months,
       ROUND(total_paid / NULLIF(DATE_PART('day', last_payment - first_payment) / 30.0, 0), 2) AS avg_monthly_value
FROM user_revenue
ORDER BY total_paid DESC
LIMIT 100;

-- Q27. Premium plan conversion funnel (Basic/Mobile -> Standard -> Premium upgrade path)
WITH ranked_subs AS (
    SELECT user_id, plan_type, start_date,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY start_date) AS sub_seq
    FROM subscriptions
)
SELECT r1.plan_type AS from_plan, r2.plan_type AS to_plan, COUNT(*) AS upgrade_count
FROM ranked_subs r1
JOIN ranked_subs r2 ON r1.user_id = r2.user_id AND r2.sub_seq = r1.sub_seq + 1
WHERE r1.plan_type <> r2.plan_type
GROUP BY r1.plan_type, r2.plan_type
ORDER BY upgrade_count DESC;

-- Q28. Payment failure rate & its impact on involuntary churn
SELECT payment_method,
       COUNT(*) AS total_attempts,
       SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failed_attempts,
       ROUND(100.0 * SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM payments
GROUP BY payment_method
ORDER BY failure_rate_pct DESC;


/* ============================== SECTION E ==================================
   USER SEGMENTATION & RFM-STYLE ANALYSIS
   ========================================================================= */

-- Q29. User segmentation: Power Users / Regular / At-Risk / Dormant (CASE + CTE)
WITH user_activity AS (
    SELECT u.user_id,
           COUNT(DISTINCT w.session_id) AS total_sessions,
           MAX(w.watch_date) AS last_watch_date,
           SUM(w.watch_duration_minutes) AS total_watch_minutes
    FROM users u
    LEFT JOIN watch_history w ON u.user_id = w.user_id
    GROUP BY u.user_id
)
SELECT
    CASE
        WHEN total_sessions >= 20 AND last_watch_date >= (SELECT MAX(watch_date) FROM watch_history) - INTERVAL '14 day'
            THEN 'Power User'
        WHEN total_sessions BETWEEN 5 AND 19
            THEN 'Regular User'
        WHEN total_sessions BETWEEN 1 AND 4
             AND last_watch_date < (SELECT MAX(watch_date) FROM watch_history) - INTERVAL '30 day'
            THEN 'At-Risk User'
        WHEN total_sessions IS NULL OR total_sessions = 0
            THEN 'Never Activated'
        ELSE 'Dormant'
    END AS user_segment,
    COUNT(*) AS user_count,
    ROUND(AVG(total_watch_minutes), 1) AS avg_watch_minutes
FROM user_activity
GROUP BY 1
ORDER BY user_count DESC;

-- Q30. RFM segmentation using NTILE window function (Recency, Frequency, Monetary)
WITH rfm_base AS (
    SELECT p.user_id,
           MAX(p.payment_date) AS last_payment_date,
           COUNT(*) AS frequency,
           SUM(p.amount_usd) AS monetary
    FROM payments p
    WHERE p.status = 'Success'
    GROUP BY p.user_id
),
rfm_scored AS (
    SELECT user_id,
           NTILE(4) OVER (ORDER BY last_payment_date DESC) AS recency_score,
           NTILE(4) OVER (ORDER BY frequency ASC) AS frequency_score,
           NTILE(4) OVER (ORDER BY monetary ASC) AS monetary_score
    FROM rfm_base
)
SELECT user_id, recency_score, frequency_score, monetary_score,
       (recency_score + frequency_score + monetary_score) AS rfm_total,
       CASE WHEN (recency_score + frequency_score + monetary_score) >= 10 THEN 'Champion'
            WHEN (recency_score + frequency_score + monetary_score) >= 7  THEN 'Loyal'
            WHEN (recency_score + frequency_score + monetary_score) >= 4  THEN 'At Risk'
            ELSE 'Hibernating' END AS rfm_segment
FROM rfm_scored
ORDER BY rfm_total DESC;

-- Q31. Age-band engagement analysis
SELECT
    CASE
        WHEN u.age < 18 THEN '<18'
        WHEN u.age BETWEEN 18 AND 24 THEN '18-24'
        WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN u.age BETWEEN 35 AND 49 THEN '35-49'
        ELSE '50+'
    END AS age_band,
    COUNT(DISTINCT u.user_id) AS users,
    ROUND(AVG(w.watch_duration_minutes), 1) AS avg_watch_minutes_per_view
FROM users u
LEFT JOIN watch_history w ON u.user_id = w.user_id
GROUP BY 1
ORDER BY 1;

-- Q32. New vs Returning subscriber growth contribution (month-over-month)
WITH monthly_subs AS (
    SELECT user_id, MIN(DATE_TRUNC('month', start_date)) AS first_month
    FROM subscriptions GROUP BY user_id
),
active_by_month AS (
    SELECT DATE_TRUNC('month', start_date) AS month, user_id
    FROM subscriptions
)
SELECT abm.month,
       COUNT(*) FILTER (WHERE abm.month = ms.first_month) AS new_subscribers,
       COUNT(*) FILTER (WHERE abm.month > ms.first_month) AS returning_subscribers
FROM active_by_month abm
JOIN monthly_subs ms ON abm.user_id = ms.user_id
GROUP BY abm.month
ORDER BY abm.month;

-- Q33. Search-to-watch conversion rate (did a search lead to a watch within 1 hour)
WITH search_events AS (
    SELECT user_id, search_date, search_query FROM search_history WHERE result_clicked = TRUE
)
SELECT
    COUNT(*) AS total_clicked_searches,
    COUNT(w.watch_id) AS resulted_in_watch,
    ROUND(100.0 * COUNT(w.watch_id) / COUNT(*), 2) AS search_to_watch_pct
FROM search_events se
LEFT JOIN watch_history w
       ON se.user_id = w.user_id
      AND w.watch_date BETWEEN se.search_date AND se.search_date + INTERVAL '1 day';

-- Q34. Top 10 highest LTV users with their acquisition channel (business prioritization)
WITH user_ltv AS (
    SELECT p.user_id, SUM(p.amount_usd) AS ltv
    FROM payments p WHERE p.status = 'Success'
    GROUP BY p.user_id
)
SELECT u.user_id, u.acquisition_channel, u.country, ul.ltv,
       RANK() OVER (ORDER BY ul.ltv DESC) AS ltv_rank
FROM user_ltv ul
JOIN users u ON ul.user_id = u.user_id
ORDER BY ltv DESC
LIMIT 10;

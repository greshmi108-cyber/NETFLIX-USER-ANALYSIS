"""
Netflix Growth & User Engagement Analytics Platform
=====================================================
Script: 01_data_generation.py
Author: Growth Analytics Team
Purpose: Generates a realistic, relationally-consistent synthetic dataset
         simulating Netflix's user, subscription, content, engagement,
         payment, and marketing data for downstream SQL/Python/Power BI analysis.

NOTE: This is SYNTHETIC data generated for portfolio/educational purposes.
It is NOT real Netflix data. Distributions (churn ~5-6%/mo, conversion
rates, ARPU, device mix, genre popularity) are modeled on publicly known
industry benchmarks for SVOD platforms to keep the data realistic.
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os

SEED = 42
np.random.seed(SEED)
rng = np.random.default_rng(SEED)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Dataset")
os.makedirs(OUT_DIR, exist_ok=True)

TODAY = datetime(2026, 6, 30)
SIGNUP_START = datetime(2022, 1, 1)

N_USERS = 15000
N_CONTENT = 1200
N_CAMPAIGNS = 60

print("Generating Netflix Growth Analytics synthetic dataset...")

# ----------------------------------------------------------------------
# 1. MARKETING CAMPAIGNS (generated first — users reference campaign_id)
# ----------------------------------------------------------------------
channels = ["Google Ads", "Meta Ads", "YouTube", "TikTok", "Influencer",
            "Affiliate", "Email", "TV/OTT", "Organic", "Referral"]
campaign_names = [f"{ch} - {q} {y}" for y in [2022, 2023, 2024, 2025, 2026]
                   for q in ["Q1", "Q2", "Q3", "Q4"] for ch in channels]
np.random.shuffle(campaign_names)
campaign_names = campaign_names[:N_CAMPAIGNS]

campaigns = pd.DataFrame({
    "campaign_id": [f"CMP{str(i).zfill(4)}" for i in range(1, N_CAMPAIGNS + 1)],
    "campaign_name": campaign_names,
    "channel": [c.split(" - ")[0] for c in campaign_names],
})
campaigns["start_date"] = [
    SIGNUP_START + timedelta(days=int(d)) for d in
    rng.integers(0, (TODAY - SIGNUP_START).days - 60, N_CAMPAIGNS)
]
campaigns["end_date"] = campaigns["start_date"] + pd.to_timedelta(rng.integers(20, 90, N_CAMPAIGNS), unit="D")
campaigns["budget_usd"] = rng.integers(5000, 500000, N_CAMPAIGNS)
campaigns["target_audience"] = rng.choice(
    ["18-24 Students", "25-34 Young Professionals", "35-50 Families",
     "50+ General", "Sports Fans", "Anime Fans", "K-Drama Fans"], N_CAMPAIGNS)
campaigns["target_region"] = rng.choice(
    ["North America", "LATAM", "EMEA", "APAC"], N_CAMPAIGNS)
campaigns["impressions"] = rng.integers(50000, 5000000, N_CAMPAIGNS)
campaigns["clicks"] = (campaigns["impressions"] * rng.uniform(0.01, 0.08, N_CAMPAIGNS)).astype(int)
campaigns["signups_attributed"] = (campaigns["clicks"] * rng.uniform(0.02, 0.12, N_CAMPAIGNS)).astype(int)
campaigns["spend_usd"] = (campaigns["budget_usd"] * rng.uniform(0.7, 1.0, N_CAMPAIGNS)).round(2)
campaigns.to_csv(os.path.join(OUT_DIR, "marketing_campaigns.csv"), index=False)
print(f"marketing_campaigns.csv -> {len(campaigns):,} rows")

# ----------------------------------------------------------------------
# 2. USERS
# ----------------------------------------------------------------------
countries = ["USA", "UK", "Canada", "India", "Brazil", "Mexico", "Germany",
             "France", "Japan", "South Korea", "Australia", "Philippines",
             "Indonesia", "Nigeria", "South Africa"]
country_weights = np.array([0.22, 0.07, 0.05, 0.14, 0.09, 0.06, 0.05, 0.05,
                             0.04, 0.04, 0.03, 0.05, 0.05, 0.03, 0.03])
country_weights = country_weights / country_weights.sum()

acquisition_channels = ["Organic", "Paid Search", "Paid Social", "Affiliate",
                         "Referral", "Influencer", "Email", "TV/OTT", "Direct"]
acq_weights = np.array([0.30, 0.16, 0.16, 0.06, 0.10, 0.06, 0.04, 0.05, 0.07])
acq_weights = acq_weights / acq_weights.sum()

signup_days = rng.integers(0, (TODAY - SIGNUP_START).days, N_USERS)
# weight signups so recent months have more (growth trend) using triangular skew
signup_days = np.sort(rng.triangular(0, (TODAY - SIGNUP_START).days, (TODAY - SIGNUP_START).days, N_USERS).astype(int))
np.random.shuffle(signup_days)

users = pd.DataFrame({
    "user_id": [f"U{str(i).zfill(6)}" for i in range(1, N_USERS + 1)],
    "signup_date": [SIGNUP_START + timedelta(days=int(d)) for d in signup_days],
    "country": rng.choice(countries, N_USERS, p=country_weights),
    "age": rng.normal(32, 10, N_USERS).clip(13, 75).astype(int),
    "gender": rng.choice(["Male", "Female", "Other"], N_USERS, p=[0.49, 0.48, 0.03]),
    "acquisition_channel": rng.choice(acquisition_channels, N_USERS, p=acq_weights),
    "signup_device": rng.choice(["Mobile", "Desktop", "Smart TV", "Tablet"], N_USERS, p=[0.45, 0.25, 0.22, 0.08]),
    "referral_user_id": None,
    "campaign_id": rng.choice(campaigns["campaign_id"], N_USERS),
    "email_opt_in": rng.choice([True, False], N_USERS, p=[0.68, 0.32]),
})

# Referral: ~10% of users referred by another (earlier signed-up) user
referral_mask = users["acquisition_channel"] == "Referral"
earlier_pool = users["user_id"].values
ref_ids = []
for i, is_ref in enumerate(referral_mask):
    if is_ref and i > 100:
        ref_ids.append(np.random.choice(earlier_pool[:i]))
    else:
        ref_ids.append(None)
users["referral_user_id"] = ref_ids

users.to_csv(os.path.join(OUT_DIR, "users.csv"), index=False)
print(f"users.csv -> {len(users):,} rows")

# ----------------------------------------------------------------------
# 3. SUBSCRIPTIONS (a user can have multiple subscription periods -> churn/reactivation)
# ----------------------------------------------------------------------
plans = ["Mobile", "Basic", "Standard", "Premium"]
plan_price = {"Mobile": 3.99, "Basic": 6.99, "Standard": 15.49, "Premium": 22.99}
plan_weights = [0.10, 0.22, 0.43, 0.25]

sub_rows = []
sub_counter = 1
for _, u in users.iterrows():
    n_periods = rng.choice([1, 2, 3], p=[0.72, 0.21, 0.07])  # some churn & resubscribe
    cur_start = u["signup_date"]
    for period in range(int(n_periods)):
        if cur_start > TODAY:
            break
        plan = rng.choice(plans, p=plan_weights)
        tenure_days = int(rng.exponential(240)) + 30
        cur_end_candidate = cur_start + timedelta(days=tenure_days)
        is_active = cur_end_candidate >= TODAY and period == n_periods - 1
        end_date = TODAY if is_active else min(cur_end_candidate, TODAY)
        status = "Active" if is_active else "Cancelled"
        cancel_reason = None
        if status == "Cancelled":
            cancel_reason = rng.choice(
                ["Price too high", "Found alternative", "Not enough content",
                 "Technical issues", "Low usage", "Temporary pause", "Other"],
                p=[0.28, 0.14, 0.20, 0.06, 0.20, 0.07, 0.05])
        sub_rows.append({
            "subscription_id": f"S{str(sub_counter).zfill(7)}",
            "user_id": u["user_id"],
            "plan_type": plan,
            "monthly_price_usd": plan_price[plan],
            "billing_cycle": rng.choice(["Monthly", "Annual"], p=[0.88, 0.12]),
            "start_date": cur_start,
            "end_date": end_date,
            "status": status,
            "auto_renew": rng.choice([True, False], p=[0.8, 0.2]),
            "cancellation_reason": cancel_reason,
            "is_free_trial": (period == 0 and rng.random() < 0.35),
        })
        sub_counter += 1
        gap = int(rng.exponential(45)) + 5
        cur_start = end_date + timedelta(days=gap)

subscriptions = pd.DataFrame(sub_rows)
subscriptions.to_csv(os.path.join(OUT_DIR, "subscriptions.csv"), index=False)
print(f"subscriptions.csv -> {len(subscriptions):,} rows")

# ----------------------------------------------------------------------
# 4. PAYMENTS (one row per billing charge within each subscription period)
# ----------------------------------------------------------------------
pay_rows = []
pay_counter = 1
payment_methods = ["Credit Card", "Debit Card", "PayPal", "UPI", "Gift Card", "Apple Pay"]
for _, s in subscriptions.iterrows():
    months = max(1, int(((s["end_date"] - s["start_date"]).days) / 30))
    cycle_days = 365 if s["billing_cycle"] == "Annual" else 30
    n_charges = max(1, ((s["end_date"] - s["start_date"]).days) // cycle_days + 1)
    charge_date = s["start_date"]
    for c in range(int(n_charges)):
        if charge_date > s["end_date"]:
            break
        failed = rng.random() < 0.03
        pay_rows.append({
            "payment_id": f"P{str(pay_counter).zfill(8)}",
            "subscription_id": s["subscription_id"],
            "user_id": s["user_id"],
            "payment_date": charge_date,
            "amount_usd": 0.0 if s["is_free_trial"] and c == 0 else s["monthly_price_usd"] * (12 if s["billing_cycle"] == "Annual" else 1),
            "payment_method": rng.choice(payment_methods, p=[0.38, 0.20, 0.15, 0.12, 0.05, 0.10]),
            "status": "Failed" if failed else "Success",
        })
        pay_counter += 1
        charge_date = charge_date + timedelta(days=cycle_days)

payments = pd.DataFrame(pay_rows)
payments.to_csv(os.path.join(OUT_DIR, "payments.csv"), index=False)
print(f"payments.csv -> {len(payments):,} rows")

# ----------------------------------------------------------------------
# 5. CONTENT LIBRARY
# ----------------------------------------------------------------------
genres = ["Drama", "Comedy", "Action", "Thriller", "Romance", "Sci-Fi",
          "Documentary", "Horror", "Anime", "Kids & Family", "Reality TV", "Crime"]
languages = ["English", "Spanish", "Korean", "Hindi", "Japanese", "French", "Portuguese", "German"]

content = pd.DataFrame({
    "content_id": [f"C{str(i).zfill(5)}" for i in range(1, N_CONTENT + 1)],
    "title": [f"Title_{i}" for i in range(1, N_CONTENT + 1)],
    "content_type": rng.choice(["Movie", "Series"], N_CONTENT, p=[0.42, 0.58]),
    "genre": rng.choice(genres, N_CONTENT),
    "language": rng.choice(languages, N_CONTENT, p=[0.35, 0.12, 0.08, 0.12, 0.08, 0.08, 0.09, 0.08]),
    "release_year": rng.integers(2015, 2027, N_CONTENT),
    "maturity_rating": rng.choice(["G", "PG", "PG-13", "R", "TV-MA"], N_CONTENT, p=[0.1, 0.15, 0.25, 0.2, 0.3]),
    "is_netflix_original": rng.choice([True, False], N_CONTENT, p=[0.35, 0.65]),
    "imdb_rating": rng.normal(6.8, 1.1, N_CONTENT).clip(2.0, 9.8).round(1),
    "production_budget_musd": rng.exponential(15, N_CONTENT).round(2),
})
content.to_csv(os.path.join(OUT_DIR, "content_library.csv"), index=False)
print(f"content_library.csv -> {len(content):,} rows")

# ----------------------------------------------------------------------
# 6. EPISODES (only for Series content)
# ----------------------------------------------------------------------
ep_rows = []
ep_counter = 1
series = content[content["content_type"] == "Series"]
for _, s in series.iterrows():
    n_seasons = rng.integers(1, 5)
    for season in range(1, n_seasons + 1):
        n_eps = rng.integers(6, 13)
        for ep in range(1, n_eps + 1):
            ep_rows.append({
                "episode_id": f"E{str(ep_counter).zfill(6)}",
                "content_id": s["content_id"],
                "season_number": season,
                "episode_number": ep,
                "duration_minutes": int(np.clip(rng.normal(45, 12), 18, 90)),
                "release_date": datetime(min(s["release_year"], 2026), 1, 1) + timedelta(days=int(rng.integers(0, 330))),
            })
            ep_counter += 1

episodes = pd.DataFrame(ep_rows)
episodes.to_csv(os.path.join(OUT_DIR, "episodes.csv"), index=False)
print(f"episodes.csv -> {len(episodes):,} rows")

# ----------------------------------------------------------------------
# 7. DEVICES
# ----------------------------------------------------------------------
device_types = ["Smart TV", "Mobile - Android", "Mobile - iOS", "Desktop - Web",
                "Tablet", "Gaming Console"]
dev_rows = []
dev_counter = 1
for _, u in users.iterrows():
    n_devices = rng.choice([1, 2, 3, 4], p=[0.35, 0.35, 0.20, 0.10])
    chosen = rng.choice(device_types, size=int(n_devices), replace=False)
    for d in chosen:
        dev_rows.append({
            "device_id": f"D{str(dev_counter).zfill(7)}",
            "user_id": u["user_id"],
            "device_type": d,
            "os_version": rng.choice(["v1", "v2", "v3", "latest"]),
            "first_used_date": u["signup_date"] + timedelta(days=int(rng.integers(0, 20))),
        })
        dev_counter += 1

devices = pd.DataFrame(dev_rows)
devices.to_csv(os.path.join(OUT_DIR, "devices.csv"), index=False)
print(f"devices.csv -> {len(devices):,} rows")

# ----------------------------------------------------------------------
# 8. SESSIONS
# ----------------------------------------------------------------------
active_users = users.merge(
    subscriptions[subscriptions["status"] == "Active"][["user_id"]].drop_duplicates(),
    on="user_id", how="inner")

TARGET_SESSIONS = 260000
sess_users = rng.choice(users["user_id"], TARGET_SESSIONS)
user_device_map = devices.groupby("user_id")["device_id"].apply(list).to_dict()
user_signup_map = users.set_index("user_id")["signup_date"].to_dict()

sess_rows = []
for i, uid in enumerate(sess_users):
    signup = user_signup_map[uid]
    max_days = max((TODAY - signup).days, 1)
    sday = signup + timedelta(days=int(rng.integers(0, max_days)))
    if sday > TODAY:
        continue
    dur = max(2, int(rng.gamma(2.0, 25)))
    devs = user_device_map.get(uid, [None])
    sess_rows.append({
        "session_id": f"SS{str(i+1).zfill(8)}",
        "user_id": uid,
        "device_id": rng.choice(devs) if devs else None,
        "session_start": sday,
        "session_duration_minutes": dur,
    })

sessions = pd.DataFrame(sess_rows)
sessions.to_csv(os.path.join(OUT_DIR, "sessions.csv"), index=False)
print(f"sessions.csv -> {len(sessions):,} rows")

# ----------------------------------------------------------------------
# 9. WATCH HISTORY (linked to sessions & content/episodes)
# ----------------------------------------------------------------------
wh_rows = []
wh_counter = 1
content_ids = content["content_id"].values
content_type_map = content.set_index("content_id")["content_type"].to_dict()
episodes_by_content = episodes.groupby("content_id")["episode_id"].apply(list).to_dict()
ep_duration_map = episodes.set_index("episode_id")["duration_minutes"].to_dict()

movie_duration = {cid: int(rng.normal(105, 20)) for cid in content[content["content_type"] == "Movie"]["content_id"]}

for _, sess in sessions.iterrows():
    n_watches = max(1, int(sess["session_duration_minutes"] // 35))
    remaining = sess["session_duration_minutes"]
    for _ in range(n_watches):
        cid = rng.choice(content_ids)
        ctype = content_type_map[cid]
        if ctype == "Series" and cid in episodes_by_content:
            eid = rng.choice(episodes_by_content[cid])
            full_dur = ep_duration_map[eid]
        else:
            eid = None
            full_dur = movie_duration.get(cid, 100)
        watched = min(full_dur, max(2, int(rng.gamma(2, full_dur / 3))))
        completion = round(min(100.0, (watched / max(full_dur, 1)) * 100), 1)
        wh_rows.append({
            "watch_id": f"W{str(wh_counter).zfill(8)}",
            "user_id": sess["user_id"],
            "session_id": sess["session_id"],
            "content_id": cid,
            "episode_id": eid,
            "device_id": sess["device_id"],
            "watch_date": sess["session_start"],
            "watch_duration_minutes": watched,
            "content_duration_minutes": full_dur,
            "completion_pct": completion,
        })
        wh_counter += 1
        if wh_counter > 500000:
            break
    if wh_counter > 500000:
        break

watch_history = pd.DataFrame(wh_rows)
watch_history.to_csv(os.path.join(OUT_DIR, "watch_history.csv"), index=False)
print(f"watch_history.csv -> {len(watch_history):,} rows")

# ----------------------------------------------------------------------
# 10. RATINGS
# ----------------------------------------------------------------------
n_ratings = 120000
rate_users = rng.choice(users["user_id"], n_ratings)
rate_content = rng.choice(content_ids, n_ratings)
ratings = pd.DataFrame({
    "rating_id": [f"R{str(i).zfill(7)}" for i in range(1, n_ratings + 1)],
    "user_id": rate_users,
    "content_id": rate_content,
    "rating": rng.choice([1, 2, 3, 4, 5], n_ratings, p=[0.03, 0.07, 0.18, 0.37, 0.35]),
    "rating_date": [SIGNUP_START + timedelta(days=int(d)) for d in rng.integers(0, (TODAY - SIGNUP_START).days, n_ratings)],
}).drop_duplicates(subset=["user_id", "content_id"])
ratings.to_csv(os.path.join(OUT_DIR, "ratings.csv"), index=False)
print(f"ratings.csv -> {len(ratings):,} rows")

# ----------------------------------------------------------------------
# 11. SEARCH HISTORY
# ----------------------------------------------------------------------
search_terms = ["stranger things", "korean drama", "action movies", "new releases",
                 "comedy series", "true crime", "romantic comedy", "anime",
                 "documentary", "thriller 2026", "kids shows", "horror movies",
                 "oscar winners", "best series 2025", "sci-fi", "family movies"]
n_search = 150000
search_history = pd.DataFrame({
    "search_id": [f"SR{str(i).zfill(7)}" for i in range(1, n_search + 1)],
    "user_id": rng.choice(users["user_id"], n_search),
    "search_query": rng.choice(search_terms, n_search),
    "search_date": [SIGNUP_START + timedelta(days=int(d)) for d in rng.integers(0, (TODAY - SIGNUP_START).days, n_search)],
    "result_clicked": rng.choice([True, False], n_search, p=[0.62, 0.38]),
})
search_history.to_csv(os.path.join(OUT_DIR, "search_history.csv"), index=False)
print(f"search_history.csv -> {len(search_history):,} rows")

# ----------------------------------------------------------------------
# SUMMARY
# ----------------------------------------------------------------------
total = (len(users) + len(subscriptions) + len(payments) + len(content) +
         len(episodes) + len(devices) + len(sessions) + len(watch_history) +
         len(ratings) + len(search_history) + len(campaigns))
print("\n" + "=" * 60)
print(f"TOTAL RECORDS GENERATED ACROSS 11 TABLES: {total:,}")
print("=" * 60)

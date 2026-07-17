/* ============================================================================
   NETFLIX GROWTH & USER ENGAGEMENT ANALYTICS PLATFORM
   Schema Definition (PostgreSQL / Snowflake / BigQuery-compatible syntax)
   ============================================================================
   Load order matters due to FK dependencies:
   campaigns -> users -> subscriptions -> payments
   content_library -> episodes
   users + devices -> sessions -> watch_history
   users + content -> ratings, search_history
   ============================================================================ */

CREATE TABLE marketing_campaigns (
    campaign_id         VARCHAR(10) PRIMARY KEY,
    campaign_name       VARCHAR(100),
    channel             VARCHAR(50),
    start_date          DATE,
    end_date            DATE,
    budget_usd          NUMERIC(12,2),
    target_audience     VARCHAR(50),
    target_region       VARCHAR(50),
    impressions         BIGINT,
    clicks              BIGINT,
    signups_attributed  BIGINT,
    spend_usd           NUMERIC(12,2)
);

CREATE TABLE users (
    user_id             VARCHAR(10) PRIMARY KEY,
    signup_date         DATE,
    country             VARCHAR(50),
    age                 INT,
    gender              VARCHAR(10),
    acquisition_channel VARCHAR(30),
    signup_device       VARCHAR(20),
    referral_user_id    VARCHAR(10) REFERENCES users(user_id),
    campaign_id         VARCHAR(10) REFERENCES marketing_campaigns(campaign_id),
    email_opt_in        BOOLEAN
);

CREATE TABLE subscriptions (
    subscription_id      VARCHAR(10) PRIMARY KEY,
    user_id              VARCHAR(10) REFERENCES users(user_id),
    plan_type            VARCHAR(20),   -- Mobile, Basic, Standard, Premium
    monthly_price_usd    NUMERIC(6,2),
    billing_cycle        VARCHAR(10),   -- Monthly, Annual
    start_date           DATE,
    end_date             DATE,
    status               VARCHAR(15),   -- Active, Cancelled
    auto_renew           BOOLEAN,
    cancellation_reason  VARCHAR(50),
    is_free_trial        BOOLEAN
);

CREATE TABLE payments (
    payment_id       VARCHAR(12) PRIMARY KEY,
    subscription_id  VARCHAR(10) REFERENCES subscriptions(subscription_id),
    user_id          VARCHAR(10) REFERENCES users(user_id),
    payment_date     DATE,
    amount_usd       NUMERIC(8,2),
    payment_method   VARCHAR(20),
    status           VARCHAR(10)   -- Success, Failed
);

CREATE TABLE content_library (
    content_id             VARCHAR(8) PRIMARY KEY,
    title                  VARCHAR(150),
    content_type           VARCHAR(10),  -- Movie, Series
    genre                  VARCHAR(30),
    language               VARCHAR(20),
    release_year           INT,
    maturity_rating        VARCHAR(10),
    is_netflix_original    BOOLEAN,
    imdb_rating            NUMERIC(3,1),
    production_budget_musd NUMERIC(10,2)
);

CREATE TABLE episodes (
    episode_id       VARCHAR(9) PRIMARY KEY,
    content_id       VARCHAR(8) REFERENCES content_library(content_id),
    season_number    INT,
    episode_number   INT,
    duration_minutes INT,
    release_date     DATE
);

CREATE TABLE devices (
    device_id        VARCHAR(9) PRIMARY KEY,
    user_id          VARCHAR(10) REFERENCES users(user_id),
    device_type      VARCHAR(30),
    os_version       VARCHAR(10),
    first_used_date  DATE
);

CREATE TABLE sessions (
    session_id               VARCHAR(10) PRIMARY KEY,
    user_id                  VARCHAR(10) REFERENCES users(user_id),
    device_id                VARCHAR(9)  REFERENCES devices(device_id),
    session_start            TIMESTAMP,
    session_duration_minutes INT
);

CREATE TABLE watch_history (
    watch_id                  VARCHAR(10) PRIMARY KEY,
    user_id                   VARCHAR(10) REFERENCES users(user_id),
    session_id                VARCHAR(10) REFERENCES sessions(session_id),
    content_id                VARCHAR(8)  REFERENCES content_library(content_id),
    episode_id                VARCHAR(9)  REFERENCES episodes(episode_id),
    device_id                 VARCHAR(9)  REFERENCES devices(device_id),
    watch_date                TIMESTAMP,
    watch_duration_minutes    INT,
    content_duration_minutes  INT,
    completion_pct             NUMERIC(5,1)
);

CREATE TABLE ratings (
    rating_id     VARCHAR(9) PRIMARY KEY,
    user_id       VARCHAR(10) REFERENCES users(user_id),
    content_id    VARCHAR(8)  REFERENCES content_library(content_id),
    rating        INT,          -- 1 to 5
    rating_date   DATE
);

CREATE TABLE search_history (
    search_id       VARCHAR(9) PRIMARY KEY,
    user_id         VARCHAR(10) REFERENCES users(user_id),
    search_query    VARCHAR(100),
    search_date     DATE,
    result_clicked  BOOLEAN
);

/* Suggested indexes for query performance on a 1M+ row fact table */
CREATE INDEX idx_watch_user       ON watch_history(user_id);
CREATE INDEX idx_watch_content    ON watch_history(content_id);
CREATE INDEX idx_watch_date       ON watch_history(watch_date);
CREATE INDEX idx_sub_user         ON subscriptions(user_id);
CREATE INDEX idx_sub_status       ON subscriptions(status);
CREATE INDEX idx_payments_user    ON payments(user_id);
CREATE INDEX idx_sessions_user    ON sessions(user_id);

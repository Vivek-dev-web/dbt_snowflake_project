-- =============================================================================
-- STEP 5 — Load data into marketing RAW tables
-- Run after 04_marketing_tables.sql
--
-- campaigns is a literal INSERT (same style as 03_load_data.sql). ad_spend and
-- order_attribution are generated procedurally from a weekly date spine and
-- deterministic hash-based "randomness" (HASH() instead of RANDOM()) so the
-- script is idempotent — re-running CREATE OR REPLACE + this script always
-- produces the same row counts and values.
-- =============================================================================

USE DATABASE DBT_PRACTICE;
USE SCHEMA   RAW;
USE WAREHOUSE DBT_WH;

-- ---------------------------------------------------------------------------
-- CAMPAIGNS
-- Four "always-on" campaigns span the full order history (2023-01 to
-- 2024-02) so every order falls inside at least one campaign window; the
-- rest are seasonal pushes.
-- ---------------------------------------------------------------------------
INSERT INTO raw.campaigns (campaign_id, campaign_name, channel, start_date, end_date, budget, status, updated_at) VALUES
(5001, 'Spring Sale 2023',          'google_ads',    '2023-01-01', '2023-03-31', 15000.00, 'completed', CURRENT_TIMESTAMP()),
(5002, 'Always-On Search',         'google_ads',    '2023-01-01', '2024-02-29', 60000.00, 'active',    CURRENT_TIMESTAMP()),
(5003, 'Black Friday Blitz',        'facebook_ads',  '2023-11-01', '2023-11-30', 20000.00, 'completed', CURRENT_TIMESTAMP()),
(5004, 'Retargeting Always-On',     'facebook_ads',  '2023-01-01', '2024-02-29', 25000.00, 'active',    CURRENT_TIMESTAMP()),
(5005, 'Instagram Influencer Push', 'instagram_ads', '2023-06-01', '2023-08-31', 12000.00, 'completed', CURRENT_TIMESTAMP()),
(5006, 'TikTok Launch',             'tiktok_ads',    '2024-01-01', '2024-02-29', 10000.00, 'active',    CURRENT_TIMESTAMP()),
(5007, 'Email Nurture Always-On',   'email',         '2023-01-01', '2024-02-29',  6000.00, 'active',    CURRENT_TIMESTAMP()),
(5008, 'Affiliate Program',         'affiliate',     '2023-01-01', '2024-02-29', 15000.00, 'active',    CURRENT_TIMESTAMP());

-- ---------------------------------------------------------------------------
-- AD SPEND
-- One row per campaign per week it was active. spend_amount is the
-- campaign's budget spread evenly across its weeks with +/-30% deterministic
-- variance; impressions/clicks are derived from a per-channel CPC/CTR
-- assumption.
-- ---------------------------------------------------------------------------
INSERT INTO raw.ad_spend (ad_spend_id, campaign_id, spend_date, impressions, clicks, spend_amount)
WITH channel_assumptions AS (
    SELECT campaign_id, channel, budget, start_date, end_date,
        CASE channel
            WHEN 'google_ads'    THEN 1.20
            WHEN 'facebook_ads'  THEN 0.85
            WHEN 'instagram_ads' THEN 0.95
            WHEN 'tiktok_ads'    THEN 0.60
            WHEN 'email'         THEN 0.15
            WHEN 'affiliate'     THEN 2.00
        END AS avg_cpc,
        CASE channel
            WHEN 'google_ads'    THEN 0.030
            WHEN 'facebook_ads'  THEN 0.015
            WHEN 'instagram_ads' THEN 0.018
            WHEN 'tiktok_ads'    THEN 0.025
            WHEN 'email'         THEN 0.080
            WHEN 'affiliate'     THEN 0.040
        END AS ctr,
        DATEDIFF('week', start_date, COALESCE(end_date, CURRENT_DATE())) + 1 AS total_weeks
    FROM raw.campaigns
),
weeks AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS week_offset
    FROM TABLE(GENERATOR(ROWCOUNT => 65))
),
campaign_weeks AS (
    SELECT
        c.campaign_id,
        c.avg_cpc,
        c.ctr,
        c.budget / c.total_weeks AS weekly_budget,
        DATEADD('week', w.week_offset, DATE_TRUNC('week', c.start_date)) AS spend_date,
        -- deterministic pseudo-random value in [0.70, 1.30]
        0.70 + (ABS(HASH(c.campaign_id, w.week_offset)) % 1000) / 1000.0 * 0.60 AS variance
    FROM channel_assumptions c
    CROSS JOIN weeks w
    WHERE DATEADD('week', w.week_offset, DATE_TRUNC('week', c.start_date))
          <= COALESCE(c.end_date, CURRENT_DATE())
),
spend AS (
    SELECT
        campaign_id,
        spend_date,
        ROUND(weekly_budget * variance, 2) AS spend_amount,
        avg_cpc,
        ctr
    FROM campaign_weeks
)
SELECT
    ROW_NUMBER() OVER (ORDER BY campaign_id, spend_date) + 6000 AS ad_spend_id,
    campaign_id,
    spend_date,
    ROUND(ROUND(spend_amount / avg_cpc) / ctr) AS impressions,
    ROUND(spend_amount / avg_cpc)              AS clicks,
    spend_amount
FROM spend;

-- ---------------------------------------------------------------------------
-- ORDER ATTRIBUTION
-- ~65% of orders (deterministic via HASH) get last-click attribution to one
-- campaign whose active window contains the order date; the rest are
-- treated as direct/organic (no row = unattributed).
-- ---------------------------------------------------------------------------
INSERT INTO raw.order_attribution (order_id, campaign_id, attribution_channel, attributed_at)
WITH eligible AS (
    SELECT
        o.order_id,
        o.order_date,
        c.campaign_id,
        c.channel,
        ROW_NUMBER() OVER (
            PARTITION BY o.order_id
            ORDER BY ABS(HASH(o.order_id, c.campaign_id))
        ) AS pick_rank
    FROM raw.orders o
    JOIN raw.campaigns c
      ON o.order_date BETWEEN c.start_date AND COALESCE(c.end_date, CURRENT_DATE())
)
SELECT
    order_id,
    campaign_id,
    channel AS attribution_channel,
    CAST(order_date AS TIMESTAMP_NTZ) AS attributed_at
FROM eligible
WHERE pick_rank = 1
  AND ABS(HASH(order_id)) % 100 < 65;

-- verify row counts
SELECT 'campaigns'          AS tbl, COUNT(*) AS row_count FROM raw.campaigns UNION ALL
SELECT 'ad_spend',          COUNT(*) FROM raw.ad_spend                       UNION ALL
SELECT 'order_attribution', COUNT(*) FROM raw.order_attribution;

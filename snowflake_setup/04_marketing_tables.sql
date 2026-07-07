-- =============================================================================
-- STEP 4 — Create marketing raw tables in the RAW schema
-- Run after 03_load_data.sql
-- =============================================================================

USE DATABASE DBT_PRACTICE;
USE SCHEMA   RAW;
USE WAREHOUSE DBT_WH;

-- ---------------------------------------------------------------------------
-- CAMPAIGNS
-- One row per marketing campaign. status/budget can change over time
-- (tracked historically via snapshots/campaigns_snapshot.sql).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.campaigns (
    campaign_id   INTEGER       NOT NULL PRIMARY KEY,
    campaign_name VARCHAR(200)  NOT NULL,
    channel       VARCHAR(30)   NOT NULL,  -- google_ads | facebook_ads | instagram_ads | tiktok_ads | email | affiliate
    start_date    DATE          NOT NULL,
    end_date      DATE,
    budget        NUMBER(12, 2) NOT NULL,
    status        VARCHAR(20)   NOT NULL,  -- planned | active | paused | completed
    updated_at    TIMESTAMP_NTZ NOT NULL
);

-- ---------------------------------------------------------------------------
-- AD SPEND
-- Weekly grain spend/performance per campaign. Append-only fact source —
-- new weeks land as new rows, which is what makes it a good incremental
-- model candidate (models/marts/marketing/fact_ad_spend.sql).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.ad_spend (
    ad_spend_id   INTEGER       NOT NULL PRIMARY KEY,
    campaign_id   INTEGER       NOT NULL REFERENCES raw.campaigns(campaign_id),
    spend_date    DATE          NOT NULL,  -- Monday of the spend week
    impressions   INTEGER       NOT NULL,
    clicks        INTEGER       NOT NULL,
    spend_amount  NUMBER(10, 2) NOT NULL,
    loaded_at     TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP()
);

-- ---------------------------------------------------------------------------
-- ORDER ATTRIBUTION
-- Last-click attribution: which campaign gets credit for an order.
-- Not every order has a row here — unattributed orders are direct/organic.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.order_attribution (
    order_id             INTEGER       NOT NULL PRIMARY KEY REFERENCES raw.orders(order_id),
    campaign_id          INTEGER       NOT NULL REFERENCES raw.campaigns(campaign_id),
    attribution_channel  VARCHAR(30)   NOT NULL,
    attributed_at        TIMESTAMP_NTZ NOT NULL
);

-- =============================================================================
-- STEP 6 — Create inventory raw tables in the RAW schema
-- Run after 05_load_marketing_data.sql
-- =============================================================================

USE DATABASE DBT_PRACTICE;
USE SCHEMA   RAW;
USE WAREHOUSE DBT_WH;

-- ---------------------------------------------------------------------------
-- WAREHOUSES
-- One row per fulfillment warehouse.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.warehouses (
    warehouse_id   INTEGER      NOT NULL PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    city           VARCHAR(100),
    state          VARCHAR(10),
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- STOCK MOVEMENTS
-- Append-only inventory ledger: every restock, sale, adjustment, and return
-- is its own row. Current stock is never stored directly — it's the running
-- sum of this ledger (see models/marts/inventory/rpt_current_stock_levels.sql).
-- Append-only + growing over time is what makes this a good incremental
-- model candidate (models/marts/inventory/fact_stock_movements.sql).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.stock_movements (
    movement_id     INTEGER       NOT NULL PRIMARY KEY,
    product_id      INTEGER       NOT NULL REFERENCES raw.products(product_id),
    warehouse_id    INTEGER       NOT NULL REFERENCES raw.warehouses(warehouse_id),
    movement_date   DATE          NOT NULL,
    movement_type   VARCHAR(20)   NOT NULL,  -- restock | sale | adjustment | return
    quantity_change INTEGER       NOT NULL,  -- positive for restock/return, negative for sale/shrinkage
    loaded_at       TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP()
);

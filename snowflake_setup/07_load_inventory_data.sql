-- =============================================================================
-- STEP 7 — Load data into inventory RAW tables
-- Run after 06_inventory_tables.sql
--
-- warehouses is a literal INSERT. stock_movements is generated procedurally
-- (deterministic HASH-based, same approach as 05_load_marketing_data.sql):
--   - restocks: every product, at every warehouse, every 8 weeks
--   - sales: one row per existing order_item, quantity deducted at a
--     hash-chosen warehouse
--   - adjustments/returns: a small hash-selected subset of restock cycles
-- =============================================================================

USE DATABASE DBT_PRACTICE;
USE SCHEMA   RAW;
USE WAREHOUSE DBT_WH;

-- ---------------------------------------------------------------------------
-- WAREHOUSES
-- ---------------------------------------------------------------------------
INSERT INTO raw.warehouses (warehouse_id, warehouse_name, city, state, is_active) VALUES
(6001, 'West Coast DC',  'Reno',   'NV', TRUE),
(6002, 'Central DC',     'Dallas', 'TX', TRUE),
(6003, 'East Coast DC',  'Newark', 'NJ', TRUE);

-- ---------------------------------------------------------------------------
-- STOCK MOVEMENTS
-- ---------------------------------------------------------------------------
INSERT INTO raw.stock_movements (movement_id, product_id, warehouse_id, movement_date, movement_type, quantity_change)
WITH cycles AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS cycle_offset
    FROM TABLE(GENERATOR(ROWCOUNT => 8))
),
warehouses AS (
    SELECT warehouse_id FROM raw.warehouses
),
products AS (
    SELECT product_id FROM raw.products
),
restock_grid AS (
    SELECT
        p.product_id,
        w.warehouse_id,
        c.cycle_offset,
        DATEADD('week', c.cycle_offset * 8, '2023-01-02'::date) AS movement_date,
        30 + (ABS(HASH(p.product_id, w.warehouse_id, c.cycle_offset)) % 40) AS restock_qty
    FROM products p
    CROSS JOIN warehouses w
    CROSS JOIN cycles c
),
restocks AS (
    SELECT
        product_id,
        warehouse_id,
        movement_date,
        'restock' AS movement_type,
        restock_qty AS quantity_change
    FROM restock_grid
),
-- a small hash-selected subset of restock cycles also gets an adjustment or return
adjustments AS (
    SELECT
        product_id,
        warehouse_id,
        DATEADD('day', 5 + (ABS(HASH(product_id, warehouse_id, cycle_offset, 'day')) % 30), movement_date) AS movement_date,
        CASE WHEN ABS(HASH(product_id, warehouse_id, cycle_offset, 'kind')) % 2 = 0
             THEN 'adjustment' ELSE 'return' END AS movement_type,
        CASE WHEN ABS(HASH(product_id, warehouse_id, cycle_offset, 'kind')) % 2 = 0
             THEN -1 * (1 + ABS(HASH(product_id, warehouse_id, cycle_offset, 'qty')) % 8)
             ELSE (1 + ABS(HASH(product_id, warehouse_id, cycle_offset, 'qty')) % 5)
        END AS quantity_change
    FROM restock_grid
    WHERE ABS(HASH(product_id, warehouse_id, cycle_offset, 'pick')) % 60 = 0
),
-- one row per existing order_item, deducted at a hash-chosen warehouse
sales AS (
    SELECT product_id, warehouse_id, movement_date, movement_type, quantity_change
    FROM (
        SELECT
            oi.product_id,
            w.warehouse_id,
            o.order_date AS movement_date,
            'sale'       AS movement_type,
            -1 * oi.quantity AS quantity_change,
            ROW_NUMBER() OVER (
                PARTITION BY oi.order_item_id
                ORDER BY ABS(HASH(oi.order_item_id, w.warehouse_id))
            ) AS rn
        FROM raw.order_items oi
        JOIN raw.orders o ON o.order_id = oi.order_id
        CROSS JOIN warehouses w
    )
    WHERE rn = 1
),
all_movements AS (
    SELECT * FROM restocks
    UNION ALL
    SELECT * FROM adjustments
    UNION ALL
    SELECT * FROM sales
)
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id, warehouse_id, movement_date) + 7000 AS movement_id,
    product_id,
    warehouse_id,
    movement_date,
    movement_type,
    quantity_change
FROM all_movements;

-- verify row counts
SELECT 'warehouses'      AS tbl, COUNT(*) AS row_count FROM raw.warehouses UNION ALL
SELECT 'stock_movements', COUNT(*) FROM raw.stock_movements;

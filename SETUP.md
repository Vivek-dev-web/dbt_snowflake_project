# dbt + Snowflake Practice Project

## Architecture

```
Snowflake (RAW schema)          dbt models
────────────────────────        ──────────────────────────────────────
departments  ─────────┐         staging views  (STAGING schema)
employees    ─────────┤──────►  stg_*
customers    ─────────┤
orders       ─────────┤         mart tables    (CORE / HR / MARKETING schemas)
order_items  ─────────┤──────►  dim_customers, fact_orders, rpt_*
products     ─────────┤         dim_employees, rpt_headcount_by_dept
campaigns    ─────────┤         fact_ad_spend (incremental), rpt_campaign_performance,
ad_spend     ─────────┤         rpt_customer_acquisition_cohorts
order_attribution ────┤
warehouses   ─────────┤         mart tables (INVENTORY schema)
stock_movements ──────┘         fact_stock_movements (incremental), rpt_current_stock_levels,
                                 rpt_inventory_reorder_alerts

                                 snapshots (SNAPSHOTS schema)
                                 campaigns_snapshot — SCD2 history of campaigns
```

Data lives in native Snowflake tables (not dbt seeds).  
dbt reads from `DBT_PRACTICE.RAW` and writes to `STAGING`, `CORE`, `HR`.

---

## One-time Snowflake setup

Run these three scripts **in order** in a Snowflake worksheet (or SnowSQL):

```sql
-- 1. Create warehouse, database, schemas, role
snowflake_setup/01_setup.sql

-- 2. Create RAW tables with constraints
snowflake_setup/02_raw_tables.sql

-- 3. INSERT all data; prints row counts at the end
snowflake_setup/03_load_data.sql

-- 4. Create marketing RAW tables (campaigns, ad_spend, order_attribution)
snowflake_setup/04_marketing_tables.sql

-- 5. Generate campaign/spend/attribution data; prints row counts at the end
snowflake_setup/05_load_marketing_data.sql

-- 6. Create inventory RAW tables (warehouses, stock_movements)
snowflake_setup/06_inventory_tables.sql

-- 7. Generate warehouse/stock-movement data; prints row counts at the end
snowflake_setup/07_load_inventory_data.sql
```

Expected row counts after step 3:

| Table        | Rows |
|---|---|
| departments  | 10   |
| employees    | 50   |
| customers    | 50   |
| products     | 37   |
| orders       | 90   |
| order_items  | 102  |

Expected row counts after step 5 (ad_spend/order_attribution are generated
procedurally from a deterministic hash, so counts are stable across reruns):

| Table              | Rows |
|---|---|
| campaigns          | 8    |
| ad_spend           | 290  |
| order_attribution  | ~62  |

Expected row counts after step 7:

| Table            | Rows |
|---|---|
| warehouses       | 3    |
| stock_movements  | ~1000 |

---

## dbt setup

### 1. Install the adapter
```bash
pip install dbt-snowflake
```

### 2. Configure credentials
Copy `profiles.yml` to `~/.dbt/profiles.yml` and fill in your `account`, `user`, `password`.

### 3. Test the connection
```bash
cd dbt_practice
dbt debug
```

### 4. Install packages
```bash
dbt deps
```

### 5. Run models
```bash
dbt run
```

### 6. Run tests
```bash
dbt test
```

### 7. Snapshot slowly-changing dimensions
```bash
dbt snapshot
```

### 8. Generate & browse docs
```bash
dbt docs generate && dbt docs serve
```

---

## Model overview

```
models/
├── staging/           -- views over RAW; renaming, casting, light derivations
│   ├── stg_employees.sql          tenure_years, salary_band
│   ├── stg_departments.sql
│   ├── stg_customers.sql          age, days_since_registration
│   ├── stg_orders.sql             order_month/quarter/year, delivered_amount
│   ├── stg_order_items.sql        gross_amount, net_amount (after discount)
│   ├── stg_products.sql           stock_status
│   ├── stg_campaigns.sql          duration_weeks
│   ├── stg_ad_spend.sql           click_through_rate, cost_per_click
│   ├── stg_order_attribution.sql
│   ├── stg_warehouses.sql
│   └── stg_stock_movements.sql
└── marts/
    ├── hr/
    │   ├── dim_employees.sql            dept + manager join, is_department_head
    │   └── rpt_headcount_by_dept.sql    headcount, payroll, tenure by dept
    ├── core/
    │   ├── dim_customers.sql            LTV aggregates + RFM category
    │   ├── fact_orders.sql              order grain, joined to customer + employee
    │   └── rpt_monthly_revenue.sql      monthly revenue with MoM growth %
    ├── marketing/
    │   ├── fact_ad_spend.sql                        incremental; weekly spend x campaign
    │   ├── rpt_campaign_performance.sql              spend/ROAS + channel ROAS rank (window fn)
    │   └── rpt_customer_acquisition_cohorts.sql      monthly cohort retention + cumulative
    │                                                  revenue (window fn)
    └── inventory/
        ├── fact_stock_movements.sql            incremental; restock/sale/adjustment/return ledger
        ├── rpt_current_stock_levels.sql        running balance per product x warehouse (window fn)
        └── rpt_inventory_reorder_alerts.sql    reorder point from sales velocity, urgency rank (window fn)

snapshots/
└── campaigns_snapshot.sql   SCD2 history of raw.campaigns (timestamp strategy on updated_at)
```

## Useful commands

```bash
# run only staging layer
dbt run --select staging

# run a model and everything downstream
dbt run --select dim_customers+

# test the mart layer only
dbt test --select marts

# compile an analysis (outputs SQL to target/compiled/)
dbt compile --select analyses/top_customers_by_ltv

# run just the marketing marts
dbt run --select marts.marketing

# run just the inventory marts
dbt run --select marts.inventory

# reprocess all ad_spend rows, ignoring the incremental filter
dbt run --select fact_ad_spend --full-refresh

# full rebuild
dbt run --full-refresh
```

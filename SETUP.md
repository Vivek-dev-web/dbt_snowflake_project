# dbt + Snowflake Practice Project

## Architecture

```
Snowflake (RAW schema)          dbt models
────────────────────────        ──────────────────────────────────────
departments  ─────────┐         staging views  (STAGING schema)
employees    ─────────┤──────►  stg_*
customers    ─────────┤
orders       ─────────┤         mart tables    (CORE / HR schemas)
order_items  ─────────┤──────►  dim_customers, fact_orders, rpt_*
products     ─────────┘         dim_employees, rpt_headcount_by_dept
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

### 7. Generate & browse docs
```bash
dbt docs generate && dbt docs serve
```

---

## Model overview

```
models/
├── staging/           -- views over RAW; renaming, casting, light derivations
│   ├── stg_employees.sql       tenure_years, salary_band
│   ├── stg_departments.sql
│   ├── stg_customers.sql       age, days_since_registration
│   ├── stg_orders.sql          order_month/quarter/year, delivered_amount
│   ├── stg_order_items.sql     gross_amount, net_amount (after discount)
│   └── stg_products.sql        stock_status
└── marts/
    ├── hr/
    │   ├── dim_employees.sql            dept + manager join, is_department_head
    │   └── rpt_headcount_by_dept.sql    headcount, payroll, tenure by dept
    └── core/
        ├── dim_customers.sql            LTV aggregates + RFM category
        ├── fact_orders.sql              order grain, joined to customer + employee
        └── rpt_monthly_revenue.sql      monthly revenue with MoM growth %
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

# full rebuild
dbt run --full-refresh
```

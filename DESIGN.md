# Design Notes: How dbt and Snowflake Fit Together

> dbt never touches your data. Snowflake does all the storing and computing —
> dbt's entire job is to write SQL, in the right order, and hand it over.
> Everything else in this document follows from that one fact.

This is the architecture reference for `dbt_practice`: why the project is
laid out the way it is, why files had to be built in the order they were,
and what every file type is actually for. It's written against the current
state of the repo (core, HR, marketing, and inventory domains).

---

## 1. Who does what

Split the two systems by responsibility, not by how often you type their name.

**Snowflake** owns storage and compute: every table, every schema, and the
warehouse (the actual CPU/memory cluster) that runs queries. Nothing in this
project lives in dbt's memory — not one row.

**dbt** owns nothing but text. It reads `.sql` and `.yml` files, resolves
`{{ ref(...) }}` and `{{ source(...) }}` Jinja tags into real Snowflake
object names, figures out the correct build order from those references, and
sends the compiled SQL to Snowflake through the connection in `profiles.yml`.
Snowflake does the rest.

```
Snowflake            dbt compiles          dbt compiles           Snowflake
raw.orders   ──►  stg_orders.sql   ──►  fact_orders.sql   ──►  CORE.FACT_ORDERS
             source()              ref() → compiled SQL     CREATE TABLE ... AS
                                                              SELECT, run on DBT_WH
```

Read left to right: a raw table becomes a dbt source, staging and mart
models reference each other by name (never a hardcoded schema), and the
final compiled SQL is executed by the Snowflake warehouse — which is also
what actually materializes the table.

---

## 2. What each file is actually for

Every file in the project falls into one of five jobs. None of them contain
data — they contain *instructions* for producing or describing data that
lives in Snowflake.

### Connection & project config

| File | Read by | Purpose |
|---|---|---|
| `profiles.yml` | dbt → Snowflake | Account, user, key, role, warehouse, default schema. The one file with real credentials in it — lives at `~/.dbt/profiles.yml`, outside the repo, precisely so it never gets committed. |
| `dbt_project.yml` | dbt only | Declares the project name, where to look for models/tests/macros/snapshots, and default config per folder — e.g. everything under `marts/marketing/` is a `table` in the `MARKETING` schema, unless a model overrides it. |
| `packages.yml` | dbt only | The dependency list — like `package.json`. Declares `dbt_utils`, `dbt_expectations`, `dbt_date` for extra macros and tests. |
| `package-lock.yml` | dbt only | Exact resolved versions, written by `dbt deps`. Committed so every machine installs the identical package set. |

### Data definition

| File | Read by | Purpose |
|---|---|---|
| `snowflake_setup/*.sql` | Snowflake only | Plain SQL, run directly in Snowflake — never through dbt. Creates the warehouse/database/role, then raw tables, then loads rows. This is the "E" and "L" of the pipeline; dbt only ever starts from the "T". |
| `models/staging/_sources.yml` | dbt only | Tells dbt "these Snowflake tables exist and here's what they're called" — without this, `{{ source('raw','orders') }}` has nothing to resolve to. Also where source-level tests (`not_null`, `relationships`, `accepted_values`) live. |

### Transformation logic

| File | Read by | Purpose |
|---|---|---|
| `models/staging/stg_*.sql` | dbt compiles → Snowflake runs | One `SELECT` per raw table: rename, cast, lower-case, add cheap derived columns. Materialized as a `view` — no new storage, just a saved query. |
| `models/marts/**/*.sql` | dbt compiles → Snowflake runs | Business-facing joins and aggregates (`dim_customers`, `fact_orders`, `rpt_campaign_performance`, `rpt_inventory_reorder_alerts`...). Usually materialized as `table` so downstream BI tools query pre-computed data, not a live join. |
| `macros/*.sql` | dbt only | Reusable Jinja+SQL functions. `generate_schema_name.sql` is what turns a model's `+schema: MARKETING` config into the real Snowflake schema `PUBLIC_MARKETING`. |
| `snapshots/*.sql` | dbt compiles → Snowflake runs | A special model type that appends a new row instead of overwriting when a tracked column changes — how `campaigns_snapshot` keeps history of a campaign's status/budget over time (SCD Type 2). |
| `analyses/*.sql` | dbt compiles only | SQL that gets Jinja-compiled but is never run or materialized — a scratchpad for ad-hoc questions that still gets to use `ref()`. |

### Testing & documentation

| File | Read by | Purpose |
|---|---|---|
| `_models.yml` (per folder) | dbt only | Per-model documentation and generic tests (`unique`, `not_null`, `accepted_values`, `relationships`, `dbt_utils.unique_combination_of_columns`). Each test compiles to a real `SELECT` that Snowflake runs — a test "failing" just means that query returned rows. |

### Generated — never hand-edit, safe to `.gitignore`

| File | Read by | Purpose |
|---|---|---|
| `target/` | dbt writes & reads | Compiled SQL and run artifacts (`manifest.json`, `run_results.json`) from the last invocation. Rebuilt every run. |
| `logs/` | dbt writes | Verbose text logs of every command — the first place to look when a run fails. |
| `.user.yml` | dbt writes | A random anonymous ID used only for dbt's opt-in usage telemetry. No project data in it. |

---

## 3. Why the build sequence isn't optional

Each step below depends on something the previous step created — a schema
to put a table in, a table to declare as a source, a source to reference
from a model. This is the order the project was built in, and the same
order every new domain (marketing, then inventory) followed.

| # | Step | Why it has to come first |
|---|---|---|
| 1 | Create Snowflake account objects (`01_setup.sql`) — warehouse, database, schemas, role | Every later object needs somewhere to live and something to authenticate as. |
| 2 | Create raw tables (`02_raw_tables.sql`, `04_marketing_tables.sql`, `06_inventory_tables.sql`) — DDL only | You can't `INSERT` into a table that doesn't exist. Structure precedes content. |
| 3 | Load rows (`03_load_data.sql`, `05_load_marketing_data.sql`, `07_load_inventory_data.sql`) — plain SQL, no dbt involved | dbt's job starts at "transform." An empty raw table transforms into an empty everything. |
| 4 | Point dbt at Snowflake (`profiles.yml`) and run `dbt debug` | Every dbt command — even parsing — needs to know which account, warehouse, and role to compile SQL for. |
| 5 | Install packages (`dbt deps`) | Tests like `dbt_utils.unique_combination_of_columns` reference macros that don't exist on disk until this step downloads them. |
| 6 | Declare sources (`_sources.yml`) | `{{ source('raw','campaigns') }}` in a model is an undefined reference until a source block gives dbt something to resolve it to. |
| 7 | Build staging models (`stg_*.sql`) | Marts call `{{ ref('stg_campaigns') }}` — dbt builds its dependency graph from these calls; a mart can't compile against a staging model that isn't in the graph yet. |
| 8 | Build mart models (`dim_/fact_/rpt_*.sql`) | dbt resolves the full `ref()` chain and topologically sorts it — you don't run things in order by hand, but you do have to have *written* them in dependency order for the graph to exist at all. |
| 9 | Attach tests (`_models.yml`) and run `dbt run` then `dbt test` | A test is a `SELECT` against the built table. Test before the table exists and there's nothing to query. |
| 10 | Snapshot, on a schedule (`dbt snapshot`) | Only useful invoked repeatedly over time — the first call just seeds row 1 of history; the value shows up when `campaigns.status` actually changes on a later call. |

---

## 4. Two worked examples

### Revenue, across the orders/marketing domains

Trace `revenue` in `rpt_campaign_performance` back to its raw source and the
dependency chain becomes concrete:

```
raw.orders → stg_orders → fact_orders.revenue → rpt_campaign_performance.attributed_revenue
```

Each arrow is a `ref()` or `source()` call — not a copy of data, a pointer
to another compiled query:

```sql
-- models/staging/stg_orders.sql  (materialized: view)
-- delivered orders only count as revenue
case when lower(status) = 'delivered' then total_amount else 0 end as delivered_amount
```

```sql
-- models/marts/core/fact_orders.sql  (materialized: table)
case when o.status = 'delivered' then i.net_amount else 0 end as revenue
-- o comes from {{ ref('stg_orders') }}, i from {{ ref('stg_order_items') }}
```

```sql
-- models/marts/marketing/rpt_campaign_performance.sql  (materialized: table)
left join {{ ref('fact_orders') }} fo using (order_id)
-- rolled up per campaign via order_attribution, then ranked:
rank() over (partition by c.channel order by div0(a.attributed_revenue, s.total_spend) desc) as roas_rank_in_channel
```

Nothing here moves data between systems — it's one SQL statement calling
into another, and Snowflake is the only thing that ever actually executes a
query or stores a byte.

### Current stock, across the inventory domain — an incremental/window-function gotcha

`rpt_current_stock_levels` needs a **running balance** per product per
warehouse: the sum of every `stock_movements` row up to a point in time.
That's a window function — and window functions need to see the *entire*
history of a partition to be correct.

`fact_stock_movements`, though, is `materialized='incremental'`: each run
only processes rows added since the last run (filtered on `loaded_at`). If
the running-balance window function lived inside that incremental model, a
normal incremental run would only see the *new* rows in scope and compute a
running balance relative to nothing — silently wrong numbers.

The fix is structural, not clever SQL: keep the incremental model dumb (just
enrich and dedupe new rows), and put the window function in a **separate,
fully-rebuilt model downstream** that reads the complete fact table:

```sql
-- models/marts/inventory/fact_stock_movements.sql  (materialized: incremental)
{% if is_incremental() %}
where loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp) from {{ this }})
{% endif %}
-- no window function here — this model never sees full history on a given run
```

```sql
-- models/marts/inventory/rpt_current_stock_levels.sql  (materialized: table, rebuilt every run)
-- reads the FULL fact_stock_movements, not a filtered slice
sum(quantity_change) over (
    partition by product_id, warehouse_id
    order by movement_date, movement_id
    rows between unbounded preceding and current row
) as running_balance
```

General rule this generalizes to: **incremental models are for the
append-only raw layer only; anything needing full history (running totals,
"latest row per key" via `qualify row_number() = 1`, cohort-style window
functions) belongs in a table model that reads the incremental model in
full.**

---

## 5. What dbt actually tells Snowflake to build

The `materialized` config is the single most consequential setting in a
model file — it decides what kind of Snowflake object gets built and how
expensive rebuilding it is.

| Config | Snowflake object | Used for, in this project |
|---|---|---|
| `view` | `CREATE VIEW` — no stored rows, query runs live each time | All of `models/staging/`: cheap to keep current, no reason to store a copy of lightly-renamed raw data. |
| `table` | `CREATE OR REPLACE TABLE ... AS SELECT` — full rebuild every run | `dim_customers`, `fact_orders`, `rpt_campaign_performance`, `rpt_current_stock_levels`, `rpt_inventory_reorder_alerts`: pre-computed joins/aggregates BI tools hit directly. |
| `incremental` | `MERGE` — only new/changed rows are processed and upserted | `fact_ad_spend`, `fact_stock_movements`: filter on a `loaded_at` timestamp so re-running doesn't reprocess unchanged history. |
| snapshot | Append-only table with `dbt_valid_from` / `dbt_valid_to` columns | `campaigns_snapshot`: every historical version of a campaign's status/budget, not just the latest. |

---

## 6. Where a model's schema name actually comes from

Nobody wrote `PUBLIC_MARKETING` or `PUBLIC_INVENTORY` anywhere. It's
assembled at compile time from two pieces:

```yaml
# dbt_project.yml
marts:
  marketing:
    +schema: MARKETING
  inventory:
    +schema: INVENTORY
```

```sql
-- macros/generate_schema_name.sql
{{ default_schema }}_{{ custom_schema_name }}
-- default_schema = target.schema from profiles.yml, i.e. "PUBLIC"
```

Concatenate the two and Snowflake ends up with `PUBLIC_MARKETING` /
`PUBLIC_INVENTORY`. Change the macro, and every schema name in the warehouse
changes with it — a good example of dbt logic having real, physical
consequences in Snowflake.

---

## 7. Domain summary

| Domain | Schema | Staging | Marts | Techniques demonstrated |
|---|---|---|---|---|
| Core (orders/customers) | `CORE` | `stg_customers`, `stg_orders`, `stg_order_items`, `stg_products` | `dim_customers`, `fact_orders`, `rpt_monthly_revenue` | Basic dimension/fact/report layering, RFM-style classification |
| HR | `HR` | `stg_employees`, `stg_departments` | `dim_employees`, `rpt_headcount_by_dept` | Dimension joins, tenure/payroll aggregation |
| Marketing | `MARKETING` | `stg_campaigns`, `stg_ad_spend`, `stg_order_attribution` | `fact_ad_spend` (incremental), `rpt_campaign_performance`, `rpt_customer_acquisition_cohorts` | Incremental models, SCD2 snapshot (`campaigns_snapshot`), window-function ranking and cumulative revenue |
| Inventory | `INVENTORY` | `stg_warehouses`, `stg_stock_movements` | `fact_stock_movements` (incremental), `rpt_current_stock_levels`, `rpt_inventory_reorder_alerts` | Incremental ledger, running-balance window function *downstream* of the incremental model, cross-domain business rules (reorder point from sales velocity) |

---

## 8. dbt Cloud specifics

The project is also wired up to dbt Cloud (project name **Analytics** —
note this doesn't match the repo or connection name, which is
"Snowflake - DBT_PRACTICE"; search by "Analytics" when looking it up in the
UI).

### Develop (IDE) vs. Jobs — two different credential paths

dbt Cloud draws a hard line between two ways of running dbt, each with its
own credentials:

- **Develop (the Cloud IDE)** — for running/testing one model at a time
  ad hoc. Uses *personal* development credentials, set per-user under
  **Profile → Credentials → (project)**. These are separate from —
  - **Deploy → Jobs** — for running the whole project on a schedule or via
    "Run Now"/the API. Uses the project's deployment connection credentials,
    configured once at the project/environment level.

Seeing a job succeed via the API or "Run Now" does **not** mean the IDE will
connect — it's the other credential set. If the IDE shows "wasn't able to
set up your development connection," it almost always means the current
user's personal dev credentials haven't been filled in yet for this project.

### The Fusion engine is stricter than the CLI

dbt Cloud's IDE runs on the **Fusion** engine, a newer/stricter parser than
the classic `dbt-core` CLI used locally. One concrete difference this
project hit: the old shorthand generic-test syntax —

```yaml
# old style — a warning on dbt-core 1.11, a hard parse error on Fusion
tests:
  - accepted_values:
      values: ['a', 'b']
  - relationships:
      to: ref('other_model')
      field: id
```

— has to be migrated to the current nested `arguments:` form, or Fusion
refuses to parse the project at all:

```yaml
# current style — works on both engines
tests:
  - accepted_values:
      arguments:
        values: ['a', 'b']
  - relationships:
      arguments:
        to: ref('other_model')
        field: id
```

Lesson: don't assume "it parses locally" means "it parses everywhere" —
dbt Cloud's IDE can be running a materially different, stricter engine than
whatever `dbt-core` version is installed on a laptop.

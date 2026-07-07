-- Running balance needs the full movement history, not just the rows an
-- incremental run added — so this window function runs here, downstream of
-- fact_stock_movements, rather than inside that incremental model.
with movements as (
    select * from {{ ref('fact_stock_movements') }}
),

running_balance as (
    select
        *,
        sum(quantity_change) over (
            partition by product_id, warehouse_id
            order by movement_date, movement_id
            rows between unbounded preceding and current row
        ) as running_balance
    from movements
),

latest as (
    select *
    from running_balance
    qualify row_number() over (
        partition by product_id, warehouse_id
        order by movement_date desc, movement_id desc
    ) = 1
)

select
    product_id,
    product_name,
    category_name,
    warehouse_id,
    warehouse_name,
    warehouse_state,
    movement_date    as as_of_date,
    running_balance  as current_stock
from latest

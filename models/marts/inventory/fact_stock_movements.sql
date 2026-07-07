{{
    config(
        materialized='incremental',
        unique_key='movement_id',
    )
}}

with movements as (
    select * from {{ ref('stg_stock_movements') }}

    {% if is_incremental() %}
    where loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp) from {{ this }})
    {% endif %}
),

products as (
    select product_id, product_name, category_name
    from {{ ref('stg_products') }}
),

warehouses as (
    select warehouse_id, warehouse_name, state as warehouse_state
    from {{ ref('stg_warehouses') }}
),

final as (
    select
        m.movement_id,
        m.product_id,
        p.product_name,
        p.category_name,
        m.warehouse_id,
        w.warehouse_name,
        w.warehouse_state,
        m.movement_date,
        m.movement_type,
        m.quantity_change,
        m.loaded_at
    from movements m
    left join products p using (product_id)
    left join warehouses w using (warehouse_id)
)

select * from final

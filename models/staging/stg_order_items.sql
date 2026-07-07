with source as (
    select * from {{ source('raw', 'order_items') }}
),

renamed as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        coalesce(discount_pct, 0)                                           as discount_pct,
        quantity * unit_price                                               as gross_amount,
        quantity * unit_price * (1 - coalesce(discount_pct, 0) / 100.0)   as net_amount,
        current_timestamp as _loaded_at
    from source
)

select * from renamed

with source as (
    select * from {{ source('raw', 'stock_movements') }}
),

renamed as (
    select
        movement_id,
        product_id,
        warehouse_id,
        cast(movement_date as date)  as movement_date,
        lower(movement_type)         as movement_type,
        quantity_change,
        cast(loaded_at as timestamp) as loaded_at,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

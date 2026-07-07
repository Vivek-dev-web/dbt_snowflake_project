with source as (
    select * from {{ source('raw', 'products') }}
),

renamed as (
    select
        product_id,
        product_name,
        category_id,
        category_name,
        unit_price,
        units_in_stock,
        supplier,
        cast(is_active as boolean) as is_active,
        case
            when units_in_stock = 0     then 'out_of_stock'
            when units_in_stock < 20    then 'low_stock'
            else 'in_stock'
        end                        as stock_status,
        current_timestamp as _loaded_at
    from source
)

select * from renamed

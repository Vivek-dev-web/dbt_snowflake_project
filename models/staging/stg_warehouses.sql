with source as (
    select * from {{ source('raw', 'warehouses') }}
),

renamed as (
    select
        warehouse_id,
        warehouse_name,
        city,
        state,
        cast(is_active as boolean) as is_active,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

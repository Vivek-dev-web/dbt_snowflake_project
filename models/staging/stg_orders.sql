with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        employee_id,
        cast(order_date as date)        as order_date,
        lower(status)                   as status,
        total_amount,
        shipping_address_city,
        shipping_address_state,
        lower(payment_method)           as payment_method,
        notes,

        -- derived
        date_trunc('month', cast(order_date as date)) as order_month,
        date_trunc('quarter', cast(order_date as date)) as order_quarter,
        year(cast(order_date as date))  as order_year,

        -- revenue only from completed orders
        case
            when lower(status) = 'delivered' then total_amount
            else 0
        end as delivered_amount,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

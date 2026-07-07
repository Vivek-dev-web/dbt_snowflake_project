with source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (
    select
        customer_id,
        first_name,
        last_name,
        first_name || ' ' || last_name  as full_name,
        lower(email)                    as email,
        phone,
        city,
        state,
        country,
        cast(registration_date as date) as registration_date,
        cast(date_of_birth as date)     as date_of_birth,
        upper(customer_segment)         as customer_segment,
        credit_limit,
        cast(is_active as boolean)      as is_active,

        -- derived
        datediff('year', cast(date_of_birth as date), current_date) as age,
        datediff('day',  cast(registration_date as date), current_date) as days_since_registration,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

with source as (
    select * from {{ source('raw', 'campaigns') }}
),

renamed as (
    select
        campaign_id,
        campaign_name,
        lower(channel)                as channel,
        cast(start_date as date)      as start_date,
        cast(end_date as date)        as end_date,
        budget,
        lower(status)                 as status,
        cast(updated_at as timestamp) as updated_at,

        -- derived
        datediff('week', cast(start_date as date), coalesce(cast(end_date as date), current_date)) + 1 as duration_weeks,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

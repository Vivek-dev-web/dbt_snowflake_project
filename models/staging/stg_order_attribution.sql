with source as (
    select * from {{ source('raw', 'order_attribution') }}
),

renamed as (
    select
        order_id,
        campaign_id,
        lower(attribution_channel)      as attribution_channel,
        cast(attributed_at as timestamp) as attributed_at,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

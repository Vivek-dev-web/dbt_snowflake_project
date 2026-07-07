with source as (
    select * from {{ source('raw', 'ad_spend') }}
),

renamed as (
    select
        ad_spend_id,
        campaign_id,
        cast(spend_date as date)      as spend_date,
        impressions,
        clicks,
        spend_amount,
        cast(loaded_at as timestamp)  as loaded_at,

        -- derived
        date_trunc('month', cast(spend_date as date)) as spend_month,
        div0(clicks, impressions)                      as click_through_rate,
        div0(spend_amount, clicks)                      as cost_per_click,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

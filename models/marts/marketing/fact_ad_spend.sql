{{
    config(
        materialized='incremental',
        unique_key='ad_spend_id',
    )
}}

with ad_spend as (
    select * from {{ ref('stg_ad_spend') }}

    {% if is_incremental() %}
    where loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp) from {{ this }})
    {% endif %}
),

campaigns as (
    select campaign_id, campaign_name, channel, status
    from {{ ref('stg_campaigns') }}
),

final as (
    select
        a.ad_spend_id,
        a.campaign_id,
        c.campaign_name,
        c.channel,
        c.status            as campaign_status,
        a.spend_date,
        a.spend_month,
        a.impressions,
        a.clicks,
        a.spend_amount,
        a.click_through_rate,
        a.cost_per_click,
        a.loaded_at
    from ad_spend a
    left join campaigns c using (campaign_id)
)

select * from final

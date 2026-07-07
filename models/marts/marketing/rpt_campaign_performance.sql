with campaigns as (
    select * from {{ ref('stg_campaigns') }}
),

spend_agg as (
    select
        campaign_id,
        sum(impressions)  as total_impressions,
        sum(clicks)       as total_clicks,
        sum(spend_amount) as total_spend
    from {{ ref('fact_ad_spend') }}
    group by 1
),

attribution as (
    select
        oa.campaign_id,
        count(distinct oa.order_id) as attributed_orders,
        sum(fo.revenue)             as attributed_revenue
    from {{ ref('stg_order_attribution') }} oa
    left join {{ ref('fact_orders') }} fo using (order_id)
    group by 1
),

final as (
    select
        c.campaign_id,
        c.campaign_name,
        c.channel,
        c.status,
        c.start_date,
        c.end_date,
        c.budget,

        coalesce(s.total_impressions, 0) as total_impressions,
        coalesce(s.total_clicks, 0)      as total_clicks,
        coalesce(s.total_spend, 0)       as total_spend,
        div0(s.total_clicks, s.total_impressions) as click_through_rate,
        div0(s.total_spend, s.total_clicks)        as cost_per_click,

        coalesce(a.attributed_orders, 0)  as attributed_orders,
        coalesce(a.attributed_revenue, 0) as attributed_revenue,
        div0(a.attributed_revenue, s.total_spend) as roas,

        -- rank each campaign's ROAS against other campaigns on the same channel
        rank() over (
            partition by c.channel
            order by div0(a.attributed_revenue, s.total_spend) desc
        ) as roas_rank_in_channel,

        -- cumulative spend across all campaigns, ordered by when they started
        sum(s.total_spend) over (
            order by c.start_date
            rows between unbounded preceding and current row
        ) as cumulative_spend_by_start_date
    from campaigns c
    left join spend_agg s using (campaign_id)
    left join attribution a using (campaign_id)
)

select * from final

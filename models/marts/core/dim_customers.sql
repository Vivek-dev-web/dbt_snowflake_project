with customers as (
    select * from {{ ref('stg_customers') }}
),

order_agg as (
    select
        customer_id,
        count(*)                            as total_orders,
        count_if(status = 'delivered')      as delivered_orders,
        count_if(status = 'cancelled')      as cancelled_orders,
        count_if(status = 'refunded')       as refunded_orders,
        sum(delivered_amount)               as lifetime_value,
        avg(delivered_amount)               as avg_order_value,
        min(order_date)                     as first_order_date,
        max(order_date)                     as last_order_date
    from {{ ref('stg_orders') }}
    group by 1
),

final as (
    select
        c.customer_id,
        c.full_name,
        c.first_name,
        c.last_name,
        c.email,
        c.phone,
        c.city,
        c.state,
        c.country,
        c.registration_date,
        c.date_of_birth,
        c.age,
        c.days_since_registration,
        c.customer_segment,
        c.credit_limit,
        c.is_active,

        coalesce(o.total_orders, 0)         as total_orders,
        coalesce(o.delivered_orders, 0)     as delivered_orders,
        coalesce(o.cancelled_orders, 0)     as cancelled_orders,
        coalesce(o.refunded_orders, 0)      as refunded_orders,
        coalesce(o.lifetime_value, 0)       as lifetime_value,
        o.avg_order_value,
        o.first_order_date,
        o.last_order_date,

        datediff('day', o.last_order_date, current_date) as days_since_last_order,

        -- RFM-style classification
        case
            when o.lifetime_value >= 5000                           then 'champion'
            when o.lifetime_value >= 2000 and o.total_orders >= 5  then 'loyal'
            when o.lifetime_value >= 1000                           then 'potential'
            when o.last_order_date >= dateadd('day', -90, current_date) then 'new'
            when o.last_order_date < dateadd('day', -180, current_date) then 'at_risk'
            else 'active'
        end as rfm_category
    from customers c
    left join order_agg o using (customer_id)
)

select * from final

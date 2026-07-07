with orders as (
    select * from {{ ref('stg_orders') }}
    where status = 'delivered'
),

customer_cohort as (
    select
        customer_id,
        date_trunc('month', min(order_date)) as cohort_month
    from orders
    group by 1
),

order_activity as (
    select
        o.customer_id,
        cc.cohort_month,
        o.order_month,
        datediff('month', cc.cohort_month, o.order_month) as months_since_acquisition,
        o.delivered_amount
    from orders o
    inner join customer_cohort cc using (customer_id)
),

cohort_month_agg as (
    select
        cohort_month,
        order_month,
        months_since_acquisition,
        count(distinct customer_id) as active_customers,
        sum(delivered_amount)       as revenue
    from order_activity
    group by 1, 2, 3
),

cohort_sizes as (
    select cohort_month, count(*) as cohort_size
    from customer_cohort
    group by 1
),

final as (
    select
        cm.cohort_month,
        cm.order_month,
        cm.months_since_acquisition,
        cs.cohort_size,
        cm.active_customers,
        div0(cm.active_customers, cs.cohort_size) as retention_rate,
        cm.revenue,

        -- cumulative revenue for this acquisition cohort, month over month
        sum(cm.revenue) over (
            partition by cm.cohort_month
            order by cm.order_month
            rows between unbounded preceding and current row
        ) as cumulative_cohort_revenue
    from cohort_month_agg cm
    left join cohort_sizes cs using (cohort_month)
)

select * from final
order by cohort_month, order_month

-- Monthly revenue rollup with MoM growth rate.
with fact as (
    select * from {{ ref('fact_orders') }}
),

monthly as (
    select
        order_year,
        order_month,
        count(distinct order_id)        as total_orders,
        count(distinct customer_id)     as unique_customers,
        sum(revenue)                    as total_revenue,
        avg(revenue)                    as avg_order_revenue,
        count_if(status = 'cancelled')  as cancelled_orders,
        count_if(status = 'refunded')   as refunded_orders
    from fact
    group by 1, 2
),

with_growth as (
    select
        *,
        lag(total_revenue) over (order by order_month) as prev_month_revenue,
        div0(
            total_revenue - lag(total_revenue) over (order by order_month),
            lag(total_revenue) over (order by order_month)
        ) * 100 as mom_growth_pct
    from monthly
)

select * from with_growth
order by order_month

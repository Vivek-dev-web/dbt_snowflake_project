with stock as (
    select * from {{ ref('rpt_current_stock_levels') }}
),

-- cross-domain: sales velocity comes from the orders domain, not inventory
sales_velocity as (
    select
        oi.product_id,
        sum(oi.quantity) as total_units_sold,
        div0(
            sum(oi.quantity),
            datediff('day', min(o.order_date), max(o.order_date)) + 1
        ) as avg_daily_units_sold
    from {{ ref('stg_order_items') }} oi
    join {{ ref('stg_orders') }} o using (order_id)
    group by 1
),

final as (
    select
        s.product_id,
        s.product_name,
        s.category_name,
        s.warehouse_id,
        s.warehouse_name,
        s.current_stock,

        coalesce(v.avg_daily_units_sold, 0) as avg_daily_units_sold,

        -- reorder point: enough stock to cover a 14-day replenishment lead time
        round(coalesce(v.avg_daily_units_sold, 0) * 14) as reorder_point,
        div0(s.current_stock, nullif(v.avg_daily_units_sold, 0)) as days_of_stock_remaining,

        case
            when s.current_stock <= 0 then 'out_of_stock'
            when s.current_stock <= round(coalesce(v.avg_daily_units_sold, 0) * 14) then 'reorder_now'
            else 'ok'
        end as stock_status,

        -- most urgent (fewest days of stock left) ranked first
        rank() over (
            order by div0(s.current_stock, nullif(v.avg_daily_units_sold, 0)) asc
        ) as urgency_rank
    from stock s
    left join sales_velocity v using (product_id)
)

select * from final

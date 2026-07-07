with orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select
        order_id,
        count(*)                as line_item_count,
        sum(gross_amount)       as gross_amount,
        sum(net_amount)         as net_amount,
        sum(gross_amount - net_amount) as total_discount
    from {{ ref('stg_order_items') }}
    group by 1
),

customers as (
    select customer_id, customer_segment, city as customer_city, state as customer_state
    from {{ ref('stg_customers') }}
),

employees as (
    select employee_id, full_name as sales_rep_name, department_name
    from {{ ref('dim_employees') }}
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.employee_id,
        o.order_date,
        o.order_month,
        o.order_quarter,
        o.order_year,
        o.status,
        o.payment_method,
        o.shipping_address_city,
        o.shipping_address_state,

        c.customer_segment,
        c.customer_city,
        c.customer_state,

        e.sales_rep_name,
        e.department_name as sales_rep_department,

        i.line_item_count,
        i.gross_amount,
        i.total_discount,
        i.net_amount,

        case when o.status = 'delivered' then i.net_amount else 0 end as revenue
    from orders o
    left join order_items i using (order_id)
    left join customers c using (customer_id)
    left join employees e using (employee_id)
)

select * from final

-- Ad-hoc analysis: top 10 customers by lifetime value with segment breakdown.
-- Run with: dbt compile --select analyses/top_customers_by_ltv
select
    customer_id,
    full_name,
    customer_segment,
    city,
    state,
    total_orders,
    lifetime_value,
    avg_order_value,
    rfm_category,
    days_since_last_order
from {{ ref('dim_customers') }}
where is_active = true
order by lifetime_value desc
limit 10

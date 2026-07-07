-- Headcount, payroll, and tenure summary rolled up to department.
with employees as (
    select * from {{ ref('dim_employees') }}
    where employment_status = 'active'
),

final as (
    select
        department_id,
        department_name,
        department_location,

        count(*)                        as headcount,
        count_if(is_department_head)    as department_heads,
        sum(salary)                     as total_payroll,
        avg(salary)                     as avg_salary,
        min(salary)                     as min_salary,
        max(salary)                     as max_salary,
        avg(tenure_years)               as avg_tenure_years,
        min(hire_date)                  as earliest_hire_date,
        max(hire_date)                  as most_recent_hire_date,

        count_if(salary_band = 'junior')     as junior_count,
        count_if(salary_band = 'mid')        as mid_count,
        count_if(salary_band = 'senior')     as senior_count,
        count_if(salary_band = 'executive')  as executive_count
    from employees
    group by 1, 2, 3
)

select * from final

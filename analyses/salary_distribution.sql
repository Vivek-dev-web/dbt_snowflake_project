-- Ad-hoc analysis: salary distribution and percentiles by department.
select
    department_name,
    count(*)                                        as headcount,
    min(salary)                                     as min_salary,
    percentile_cont(0.25) within group (order by salary) as p25_salary,
    percentile_cont(0.50) within group (order by salary) as median_salary,
    percentile_cont(0.75) within group (order by salary) as p75_salary,
    max(salary)                                     as max_salary,
    avg(salary)                                     as avg_salary,
    sum(salary)                                     as total_payroll
from {{ ref('dim_employees') }}
where employment_status = 'active'
group by 1
order by avg_salary desc

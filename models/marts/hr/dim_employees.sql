with employees as (
    select * from {{ ref('stg_employees') }}
),

departments as (
    select * from {{ ref('stg_departments') }}
),

managers as (
    select
        employee_id,
        full_name as manager_name,
        job_title as manager_title
    from employees
),

final as (
    select
        e.employee_id,
        e.full_name,
        e.first_name,
        e.last_name,
        e.email,
        e.phone,
        e.job_title,
        e.salary,
        e.salary_band,
        e.hire_date,
        e.tenure_years,
        e.employment_status,
        e.city,
        e.state,

        d.department_id,
        d.department_name,
        d.location          as department_location,

        m.manager_name,
        m.manager_title,

        case when e.manager_id is null then true else false end as is_department_head
    from employees e
    left join departments d using (department_id)
    left join managers m on e.manager_id = m.employee_id
)

select * from final

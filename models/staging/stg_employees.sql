with source as (
    select * from {{ source('raw', 'employees') }}
),

renamed as (
    select
        employee_id,
        first_name,
        last_name,
        first_name || ' ' || last_name                          as full_name,
        lower(email)                                            as email,
        phone,
        department_id,
        job_title,
        salary,
        cast(hire_date as date)                                 as hire_date,
        manager_id,
        lower(employment_status)                                as employment_status,
        city,
        state,

        -- derived
        datediff('year', cast(hire_date as date), current_date) as tenure_years,
        case
            when salary < 80000  then 'junior'
            when salary < 120000 then 'mid'
            when salary < 160000 then 'senior'
            else 'executive'
        end                                                     as salary_band,

        current_timestamp as _loaded_at
    from source
)

select * from renamed

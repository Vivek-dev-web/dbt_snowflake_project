with source as (
    select * from {{ source('raw', 'departments') }}
),

renamed as (
    select
        department_id,
        department_name,
        location,
        manager_id,
        budget,
        current_timestamp as _loaded_at
    from source
)

select * from renamed

with source as (
    select * from {{ ref('transaction_resolutions') }}
),

renamed as (
    select
        transaction_id,
        resolution_status,
        -- source dates are dd/mm/yyyy, which sqlite's date() can't parse
        date(
            substr(resolution_date, 7, 4) || '-'
            || substr(resolution_date, 4, 2) || '-'
            || substr(resolution_date, 1, 2)
        ) as resolution_date
    from source
)

select * from renamed

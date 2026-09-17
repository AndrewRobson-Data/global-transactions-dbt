with source as (
    select * from {{ ref('client_contracts') }}
),

renamed as (
    select
        client_id,
        cast(date(contract_start_date) as text) as contract_start_date,
        cast(date(contract_start_date, '+' || contract_duration_months || ' months', '-1 day') as text) as contract_end_date,
        contract_duration_months,
        spend_threshold,
        discounted_fee_margin
    from source
)

select * from renamed

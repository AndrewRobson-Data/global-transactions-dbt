with source as (
    select * from {{ ref('client_contracts') }}
),

-- sqlite's '+N months' rolls 31 Jan into March, so add months to the 1st
-- and cap the day at the end of the target month
anniversary as (
    select
        *,
        min(
            date(contract_start_date, 'start of month', '+' || contract_duration_months || ' months',
                '+' || (cast(strftime('%d', contract_start_date) as integer) - 1) || ' days'),
            date(contract_start_date, 'start of month', '+' || (contract_duration_months + 1) || ' months', '-1 day')
        ) as contract_anniversary_date
    from source
),

renamed as (
    select
        client_id,
        cast(date(contract_start_date) as text) as contract_start_date,
        cast(date(contract_anniversary_date, '-1 day') as text) as contract_end_date,
        contract_duration_months,
        spend_threshold,
        discounted_fee_margin
    from anniversary
)

select * from renamed

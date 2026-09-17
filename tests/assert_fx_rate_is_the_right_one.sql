-- checks the right rate was picked, not just that the arithmetic is self-consistent:
-- a refund takes its payment's rate, anything else takes the latest rate on or before its own date
with converted as (
    select * from {{ ref('int_transactions_converted_to_gbp') }}
),

expected as (
    select
        converted.transaction_id,
        converted.rate_date,
        converted.exchange_rate_to_gbp,
        case
            when payments.transaction_id is not null then payments.rate_date
            else (
                select max(rates.rate_date)
                from {{ ref('stg_currency_rates') }} as rates
                where rates.currency = converted.currency
                    and rates.rate_date <= converted.transaction_date
            )
        end as expected_rate_date,
        case
            when payments.transaction_id is not null then payments.exchange_rate_to_gbp
        end as expected_payment_rate
    from converted
    left join converted as payments
        on converted.linked_transaction_id = payments.transaction_id
)

select *
from expected
where rate_date is not expected_rate_date
    or (expected_payment_rate is not null and exchange_rate_to_gbp is not expected_payment_rate)

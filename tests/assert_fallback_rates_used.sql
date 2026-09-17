{{ config(severity='warn') }}

select
    transaction_id,
    currency,
    transaction_date,
    rate_date
from {{ ref('int_transactions_converted_to_gbp') }}
where is_fallback_rate

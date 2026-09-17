select
    transaction_id,
    transaction_amount,
    exchange_rate_to_gbp,
    amount_gbp
from {{ ref('int_transactions_converted_to_gbp') }}
where abs(amount_gbp - transaction_amount * exchange_rate_to_gbp) > 0.0001

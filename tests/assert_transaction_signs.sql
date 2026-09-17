select
    transaction_id,
    transaction_type,
    signed_amount_gbp
from {{ ref('int_transactions_revenue_recognised') }}
where (transaction_type = 'payment' and signed_amount_gbp <= 0)
    or (transaction_type != 'payment' and signed_amount_gbp >= 0)

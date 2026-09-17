select
    refunds.transaction_id,
    refunds.transaction_date,
    payments.transaction_date as payment_date
from {{ ref('stg_transactions') }} as refunds
inner join {{ ref('stg_transactions') }} as payments
    on refunds.linked_transaction_id = payments.transaction_id
where refunds.transaction_type = 'refund'
    and refunds.transaction_date < payments.transaction_date

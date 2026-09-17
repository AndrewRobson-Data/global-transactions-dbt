{{ config(severity='warn') }}

-- informational: payments refunded more than once, or refunded for more than they were worth
select
    payments.transaction_id,
    payments.amount_gbp,
    count(*) as refunds,
    sum(refunds.amount_gbp) as refunded_gbp
from {{ ref('int_transactions_converted_to_gbp') }} as refunds
inner join {{ ref('int_transactions_converted_to_gbp') }} as payments
    on refunds.linked_transaction_id = payments.transaction_id
where refunds.transaction_type = 'refund'
group by payments.transaction_id, payments.amount_gbp
having count(*) > 1
    or sum(refunds.amount_gbp) > payments.amount_gbp + 0.01

select
    transactions.transaction_id,
    transactions.client_id,
    transactions.applied_fee_margin
from {{ ref('int_transactions_with_discount_status') }} as transactions
left join {{ ref('stg_client_contracts') }} as contracts
    on transactions.client_id = contracts.client_id
where contracts.client_id is null
    and (transactions.is_discount_applied or transactions.applied_fee_margin != 0.2)

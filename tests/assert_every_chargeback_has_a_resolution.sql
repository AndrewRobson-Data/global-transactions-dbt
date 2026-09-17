select
    transactions.transaction_id,
    transactions.transaction_date
from {{ ref('stg_transactions') }} as transactions
left join {{ ref('stg_transaction_resolutions') }} as resolutions
    on transactions.transaction_id = resolutions.transaction_id
where transactions.transaction_type = 'chargeback'
    and resolutions.resolution_status is null

select
    resolutions.transaction_id,
    transactions.transaction_type
from {{ ref('stg_transaction_resolutions') }} as resolutions
inner join {{ ref('stg_transactions') }} as transactions
    on resolutions.transaction_id = transactions.transaction_id
where transactions.transaction_type != 'chargeback'

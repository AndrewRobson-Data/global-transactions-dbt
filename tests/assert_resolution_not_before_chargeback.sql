select
    resolutions.transaction_id,
    transactions.transaction_date,
    resolutions.resolution_date
from {{ ref('stg_transaction_resolutions') }} as resolutions
inner join {{ ref('stg_transactions') }} as transactions
    on resolutions.transaction_id = transactions.transaction_id
where resolutions.resolution_date < transactions.transaction_date

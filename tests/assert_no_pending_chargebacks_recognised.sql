select recognised.transaction_id
from {{ ref('int_transactions_revenue_recognised') }} as recognised
inner join {{ ref('stg_transaction_resolutions') }} as resolutions
    on recognised.transaction_id = resolutions.transaction_id
where resolutions.resolution_status != 'resolved'

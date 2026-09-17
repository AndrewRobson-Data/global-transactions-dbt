select
    transaction_id,
    transaction_date,
    recognition_date
from {{ ref('int_transactions_revenue_recognised') }}
where recognition_date < transaction_date

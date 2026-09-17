{{ config(severity='warn') }}

-- age is measured against the latest transaction, as the data is a static snapshot
with as_of as (
    select max(transaction_date) as as_of_date
    from {{ ref('stg_transactions') }}
)

select
    resolutions.transaction_id,
    transactions.transaction_date,
    julianday(as_of.as_of_date) - julianday(transactions.transaction_date) as days_pending
from {{ ref('stg_transaction_resolutions') }} as resolutions
inner join {{ ref('stg_transactions') }} as transactions
    on resolutions.transaction_id = transactions.transaction_id
cross join as_of
where resolutions.resolution_status = 'pending'
    and julianday(as_of.as_of_date) - julianday(transactions.transaction_date) > 30

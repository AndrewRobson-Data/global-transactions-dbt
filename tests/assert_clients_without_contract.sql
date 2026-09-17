-- informational: clients without a contract are charged the default margin throughout
{{ config(severity='warn') }}

select
    transactions.client_id,
    count(*) as transactions
from {{ ref('stg_transactions') }} as transactions
left join {{ ref('stg_client_contracts') }} as contracts
    on transactions.client_id = contracts.client_id
where contracts.client_id is null
group by transactions.client_id

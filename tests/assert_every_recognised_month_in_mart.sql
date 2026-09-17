-- the reconciliations start from the mart, so they can't see a client-month the mart lost entirely
select distinct
    recognised.client_id,
    recognised.recognition_month
from {{ ref('int_transactions_revenue_recognised') }} as recognised
where not exists (
    select 1
    from {{ ref('fct_client_monthly_revenue') }} as mart
    where mart.client_id = recognised.client_id
        and mart.month_start = recognised.recognition_month
)

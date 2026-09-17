-- the mart re-aggregates contract spend, so check it against the transaction-level model
with mart as (
    select
        client_id,
        month_start,
        spend_to_date_gbp
    from {{ ref('fct_client_monthly_revenue') }}
    where spend_to_date_gbp is not null
),

transactions as (
    select
        client_id,
        strftime('%Y-%m-01', transaction_date) as month_start,
        amount_gbp
    from {{ ref('int_transactions_revenue_recognised') }}
    where transaction_type = 'payment'
        and is_in_contract
),

expected as (
    select
        mart.client_id,
        mart.month_start,
        mart.spend_to_date_gbp,
        coalesce(sum(transactions.amount_gbp), 0) as expected_spend_gbp
    from mart
    left join transactions
        on mart.client_id = transactions.client_id
        and transactions.month_start <= mart.month_start
    group by mart.client_id, mart.month_start, mart.spend_to_date_gbp
)

select *
from expected
where abs(spend_to_date_gbp - expected_spend_gbp) > 0.01

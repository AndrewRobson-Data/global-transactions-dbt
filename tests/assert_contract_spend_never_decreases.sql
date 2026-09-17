with ordered as (
    select
        transaction_id,
        client_id,
        payments_spend_before_gbp,
        lag(payments_spend_before_gbp) over (
            partition by client_id
            order by transaction_date, transaction_id
        ) as previous_spend_gbp
    from {{ ref('int_transactions_with_discount_status') }}
)

select *
from ordered
where payments_spend_before_gbp < previous_spend_gbp

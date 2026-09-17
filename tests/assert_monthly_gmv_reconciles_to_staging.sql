-- catches any client or payment dropped by a join between staging and the mart
with mart as (
    select
        client_id,
        month_start,
        gross_gmv_gbp
    from {{ ref('fct_client_monthly_revenue') }}
),

converted as (
    select
        client_id,
        strftime('%Y-%m-01', transaction_date) as month_start,
        round(sum(amount_gbp), 2) as gross_gmv_gbp
    from {{ ref('int_transactions_converted_to_gbp') }}
    where transaction_type = 'payment'
    group by client_id, strftime('%Y-%m-01', transaction_date)
)

select
    mart.client_id,
    mart.month_start,
    mart.gross_gmv_gbp,
    converted.gross_gmv_gbp as converted_gmv_gbp
from mart
left join converted
    on mart.client_id = converted.client_id
    and mart.month_start = converted.month_start
where mart.gross_gmv_gbp != coalesce(converted.gross_gmv_gbp, 0)

-- catches any client or payment dropped by a join between staging and the mart
with mart as (
    select sum(gross_gmv_gbp) as gross_gmv_gbp
    from {{ ref('fct_client_monthly_revenue') }}
),

converted as (
    select sum(amount_gbp) as gross_gmv_gbp
    from {{ ref('int_transactions_converted_to_gbp') }}
    where transaction_type = 'payment'
)

select *
from mart
cross join converted
where abs(mart.gross_gmv_gbp - converted.gross_gmv_gbp) > 0.01

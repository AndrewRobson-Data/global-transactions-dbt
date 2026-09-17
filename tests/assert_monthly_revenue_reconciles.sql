with mart as (
    select
        sum(revenue_gbp) as revenue_gbp,
        sum(net_gmv_gbp) as net_gmv_gbp
    from {{ ref('fct_client_monthly_revenue') }}
),

recognised as (
    select
        sum(revenue_gbp) as revenue_gbp,
        sum(signed_amount_gbp) as net_gmv_gbp
    from {{ ref('int_transactions_revenue_recognised') }}
)

select *
from mart
cross join recognised
where abs(mart.revenue_gbp - recognised.revenue_gbp) > 0.01
    or abs(mart.net_gmv_gbp - recognised.net_gmv_gbp) > 0.01

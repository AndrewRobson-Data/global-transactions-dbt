-- per client-month, not just in total, so an error in one month can't net out against another
with mart as (
    select
        client_id,
        month_start,
        revenue_gbp,
        net_gmv_gbp
    from {{ ref('fct_client_monthly_revenue') }}
),

recognised as (
    select
        client_id,
        recognition_month as month_start,
        sum(revenue_gbp) as revenue_gbp,
        sum(signed_amount_gbp) as net_gmv_gbp
    from {{ ref('int_transactions_revenue_recognised') }}
    group by client_id, recognition_month
)

select
    mart.client_id,
    mart.month_start,
    mart.revenue_gbp,
    recognised.revenue_gbp as recognised_revenue_gbp
from mart
left join recognised
    on mart.client_id = recognised.client_id
    and mart.month_start = recognised.month_start
where mart.revenue_gbp != round(coalesce(recognised.revenue_gbp, 0), 2)
    or mart.net_gmv_gbp != round(coalesce(recognised.net_gmv_gbp, 0), 2)

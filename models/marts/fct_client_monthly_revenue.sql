with client_months as (
    select * from {{ ref('int_client_months') }}
),

recognised as (
    select * from {{ ref('int_transactions_revenue_recognised') }}
),

contracts as (
    select * from {{ ref('stg_client_contracts') }}
),

monthly as (
    select
        client_id,
        recognition_month as month_start,
        sum(revenue_gbp) as revenue_gbp,
        sum(case when transaction_type = 'payment' then amount_gbp else 0 end) as gross_gmv_gbp,
        sum(signed_amount_gbp) as net_gmv_gbp,
        sum(case when transaction_type = 'payment' and is_in_contract then amount_gbp else 0 end) as contract_payments_gbp,
        max(is_discount_applied) as is_discount_applied
    from recognised
    group by client_id, recognition_month
),

joined as (
    select
        client_months.client_id,
        client_months.month_start,
        coalesce(monthly.revenue_gbp, 0) as revenue_gbp,
        coalesce(monthly.gross_gmv_gbp, 0) as gross_gmv_gbp,
        coalesce(monthly.net_gmv_gbp, 0) as net_gmv_gbp,
        coalesce(monthly.contract_payments_gbp, 0) as contract_payments_gbp,
        coalesce(monthly.is_discount_applied, 0) as is_discount_applied,
        contracts.client_id is not null as has_contract,
        client_months.month_start between date(contracts.contract_start_date, 'start of month')
            and contracts.contract_end_date as is_contract_active,
        contracts.spend_threshold
    from client_months
    left join monthly
        on client_months.client_id = monthly.client_id
        and client_months.month_start = monthly.month_start
    left join contracts
        on client_months.client_id = contracts.client_id
),

final as (
    select
        client_id,
        month_start,
        cast(revenue_gbp as real) as revenue_gbp,
        cast(gross_gmv_gbp as real) as gross_gmv_gbp,
        cast(net_gmv_gbp as real) as net_gmv_gbp,
        cast(has_contract as integer) as has_contract,
        cast(coalesce(is_contract_active, 0) as integer) as is_contract_active,
        spend_threshold,
        cast(case when has_contract then sum(contract_payments_gbp) over (
            partition by client_id
            order by month_start
        ) end as real) as spend_to_date_gbp,
        cast(
            sum(contract_payments_gbp) over (partition by client_id order by month_start)
            / spend_threshold
        as real) as pct_of_threshold,
        cast(coalesce(
            sum(contract_payments_gbp) over (partition by client_id order by month_start) >= spend_threshold,
            0
        ) as integer) as is_threshold_reached,
        cast(is_discount_applied as integer) as is_discount_applied
    from joined
)

select * from final

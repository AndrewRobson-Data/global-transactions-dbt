with recognised as (
    select * from {{ ref('int_transactions_revenue_recognised') }}
),

clients as (
    select distinct client_id
    from {{ ref('stg_transactions') }}
),

-- sqlite has no date spine function, so generate months recursively
months as (
    select min(recognition_month) as month_start, max(recognition_month) as last_month
    from recognised

    union all

    select cast(date(month_start, '+1 month') as text), last_month
    from months
    where month_start < last_month
),

final as (
    select
        clients.client_id,
        cast(months.month_start as text) as month_start
    from clients
    cross join months
)

select * from final

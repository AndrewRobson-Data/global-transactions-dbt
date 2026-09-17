with transactions as (
    select * from {{ ref('stg_transactions') }}
),

currency_rates as (
    select * from {{ ref('stg_currency_rates') }}
),

-- latest rate on or before the transaction date, so gaps in the rates feed fall back to the previous day
rate_dates as (
    select
        transactions.transaction_id,
        max(currency_rates.rate_date) as rate_date
    from transactions
    left join currency_rates
        on transactions.currency = currency_rates.currency
        and currency_rates.rate_date <= transactions.transaction_date
    group by transactions.transaction_id
),

final as (
    select
        transactions.*,
        currency_rates.rate_date,
        currency_rates.exchange_rate_to_gbp,
        cast(currency_rates.rate_date < transactions.transaction_date as integer) as is_fallback_rate,
        cast(transactions.transaction_amount * currency_rates.exchange_rate_to_gbp as real) as amount_gbp
    from transactions
    left join rate_dates
        on transactions.transaction_id = rate_dates.transaction_id
    left join currency_rates
        on transactions.currency = currency_rates.currency
        and rate_dates.rate_date = currency_rates.rate_date
)

select * from final

with transactions as (
    select * from {{ ref('stg_transactions') }}
),

currency_rates as (
    select * from {{ ref('stg_currency_rates') }}
),

-- latest rate on or before the transaction date, so gaps in the rates feed fall back to an earlier day
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

own_rate as (
    select
        transactions.*,
        currency_rates.rate_date,
        currency_rates.exchange_rate_to_gbp
    from transactions
    left join rate_dates
        on transactions.transaction_id = rate_dates.transaction_id
    left join currency_rates
        on transactions.currency = currency_rates.currency
        and rate_dates.rate_date = currency_rates.rate_date
),

-- a refund reverses a specific payment, so it converts at that payment's rate.
-- otherwise a fully refunded sale leaves an fx residual in gmv and revenue
final as (
    select
        own_rate.transaction_id,
        own_rate.client_id,
        own_rate.transaction_amount,
        own_rate.transaction_type,
        own_rate.transaction_date,
        own_rate.platform_fee_margin,
        own_rate.currency,
        own_rate.linked_transaction_id,
        cast(coalesce(payments.rate_date, own_rate.rate_date) as text) as rate_date,
        cast(coalesce(payments.exchange_rate_to_gbp, own_rate.exchange_rate_to_gbp) as real) as exchange_rate_to_gbp,
        -- only meaningful where the row uses its own rate; a refund inherits its payment's
        cast(payments.transaction_id is null and own_rate.rate_date < own_rate.transaction_date as integer) as is_fallback_rate,
        cast(payments.transaction_id is not null as integer) as uses_original_payment_rate,
        cast(
            own_rate.transaction_amount * coalesce(payments.exchange_rate_to_gbp, own_rate.exchange_rate_to_gbp)
        as real) as amount_gbp
    from own_rate
    left join own_rate as payments
        on own_rate.linked_transaction_id = payments.transaction_id
)

select * from final

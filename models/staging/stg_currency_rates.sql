with source as (
    select * from {{ ref('currency_rates') }}
),

renamed as (
    select
        currency,
        cast(date(rate_date) as text) as rate_date,
        exchange_rate_to_gbp
    from source
)

select * from renamed

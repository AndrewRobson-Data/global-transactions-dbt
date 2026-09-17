with source as (
    select * from {{ ref('transactions') }}
),

renamed as (
    select
        transaction_id,
        client_id,
        transaction_amount,
        transaction_type,
        cast(date(transaction_date) as text) as transaction_date,
        platform_fee_margin,
        currency,
        linked_transaction_id
    from source
)

select * from renamed

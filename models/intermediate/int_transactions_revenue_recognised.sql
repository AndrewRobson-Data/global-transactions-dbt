with transactions as (
    select * from {{ ref('int_transactions_with_discount_status') }}
),

resolutions as (
    select * from {{ ref('stg_transaction_resolutions') }}
),

-- chargebacks are recognised when resolved; pending ones are excluded until then
recognised as (
    select
        transactions.*,
        resolutions.resolution_date,
        cast(
            case
                when transactions.transaction_type = 'chargeback' then resolutions.resolution_date
                else transactions.transaction_date
            end
        as text) as recognition_date
    from transactions
    left join resolutions
        on transactions.transaction_id = resolutions.transaction_id
    where transactions.transaction_type != 'chargeback'
        or resolutions.resolution_status = 'resolved'
),

final as (
    select
        transaction_id,
        client_id,
        transaction_type,
        transaction_date,
        original_payment_date,
        resolution_date,
        recognition_date,
        cast(strftime('%Y-%m-01', recognition_date) as text) as recognition_month,
        is_in_contract,
        spend_threshold,
        payments_spend_before_gbp,
        is_discount_applied,
        applied_fee_margin,
        amount_gbp,
        cast(case when transaction_type = 'payment' then amount_gbp else -amount_gbp end as real) as signed_amount_gbp,
        cast(case when transaction_type = 'payment' then amount_gbp else -amount_gbp end * applied_fee_margin as real) as revenue_gbp
    from recognised
)

select * from final

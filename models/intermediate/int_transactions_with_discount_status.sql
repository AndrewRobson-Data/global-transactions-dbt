with transactions as (
    select * from {{ ref('int_transactions_converted_to_gbp') }}
),

contracts as (
    select * from {{ ref('stg_client_contracts') }}
),

with_contract as (
    select
        transactions.*,
        contracts.client_id is not null as is_in_contract,
        contracts.spend_threshold,
        contracts.discounted_fee_margin
    from transactions
    left join contracts
        on transactions.client_id = contracts.client_id
        and transactions.transaction_date between contracts.contract_start_date and contracts.contract_end_date
),

-- spend is in-contract payments only, and excludes the current transaction,
-- so the payment that crosses the threshold is still charged the default margin
with_spend as (
    select
        *,
        coalesce(
            sum(case when is_in_contract and transaction_type = 'payment' then amount_gbp end) over (
                partition by client_id
                order by transaction_date, transaction_id
                rows between unbounded preceding and 1 preceding
            ),
            0
        ) as payments_spend_before_gbp
    from with_contract
),

with_margin as (
    select
        *,
        is_in_contract and payments_spend_before_gbp >= spend_threshold as is_discount_eligible
    from with_spend
),

-- refunds reverse the fee at the margin charged on the payment they refund
final as (
    select
        with_margin.transaction_id,
        with_margin.client_id,
        with_margin.transaction_type,
        with_margin.transaction_date,
        with_margin.linked_transaction_id,
        with_margin.currency,
        with_margin.transaction_amount,
        with_margin.amount_gbp,
        with_margin.is_in_contract,
        with_margin.spend_threshold,
        with_margin.payments_spend_before_gbp,
        payments.transaction_date as original_payment_date,
        case
            when with_margin.transaction_type = 'refund' then payments.is_discount_eligible
            else with_margin.is_discount_eligible
        end as is_discount_applied,
        case
            when with_margin.transaction_type = 'refund' and payments.is_discount_eligible then payments.discounted_fee_margin
            when with_margin.transaction_type = 'refund' then payments.platform_fee_margin
            when with_margin.is_discount_eligible then with_margin.discounted_fee_margin
            else with_margin.platform_fee_margin
        end as applied_fee_margin
    from with_margin
    left join with_margin as payments
        on with_margin.linked_transaction_id = payments.transaction_id
)

select * from final

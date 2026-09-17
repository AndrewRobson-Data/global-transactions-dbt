select
    (select count(*) from {{ ref('stg_transactions') }}) as staging_rows,
    (select count(*) from {{ ref('int_transactions_converted_to_gbp') }}) as converted_rows
where staging_rows != converted_rows

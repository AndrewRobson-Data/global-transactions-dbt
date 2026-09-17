with counts as (
    select
        count(*) as spine_rows,
        count(distinct client_id) * count(distinct month_start) as expected_rows
    from {{ ref('int_client_months') }}
)

select
    counts.spine_rows,
    counts.expected_rows
from counts
where counts.spine_rows != counts.expected_rows

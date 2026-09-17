select
    count(*) as spine_rows,
    count(distinct client_id) * count(distinct month_start) as expected_rows
from {{ ref('int_client_months') }}
having count(*) != count(distinct client_id) * count(distinct month_start)

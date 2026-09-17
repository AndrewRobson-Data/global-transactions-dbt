-- sqlite's date() silently normalises impossible dates, e.g. 31/04/2024 becomes 2024-05-01
select
    resolutions.transaction_id,
    source.resolution_date as source_date,
    resolutions.resolution_date as parsed_date
from {{ ref('stg_transaction_resolutions') }} as resolutions
inner join {{ ref('transaction_resolutions') }} as source
    on resolutions.transaction_id = source.transaction_id
where resolutions.resolution_date is not null
    and strftime('%d/%m/%Y', resolutions.resolution_date) != source.resolution_date

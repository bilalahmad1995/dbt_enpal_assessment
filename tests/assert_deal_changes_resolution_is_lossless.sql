-- Lifecycle resolution must neither drop nor duplicate change-log rows.
-- Returns a row (= failure) when the row counts of staging and the resolved model differ.

with counts as (

    select
        (select count(*) from {{ ref('stg_pipedrive__deal_changes') }}) as staging_rows,
        (select count(*) from {{ ref('int_deal_changes_resolved') }}) as resolved_rows

)

select
    staging_rows,
    resolved_rows
from counts
where staging_rows <> resolved_rows

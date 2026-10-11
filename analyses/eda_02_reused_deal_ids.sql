-- EDA 02 – reused deal ids
-- 5 deal ids have two add_time events. Their histories are interleaved (stage goes 1,2,3,4 then
-- 1,2 again while the first deal continues to 5 and 8), so they are two deals sharing one id –
-- not a re-opened deal. This explains ALL backward / repeated stage moves in the extract.

-- 1. Full history of the reused ids: note the two distinct times of day per id.
select
    deal_id,
    change_time,
    change_time::time as time_of_day,
    changed_field_key,
    new_value
from {{ source('pipedrive', 'deal_changes') }}
where deal_id in (
    select deal_id
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'add_time'
    group by deal_id
    having count(*) > 1
)
order by deal_id, change_time;

-- 2. Every change shares the time of day of its deal's add_time:
--    0 mismatches over the 15,326 rows of single-creation deals ...
with creations as (
    select deal_id, change_time::time as creation_time_of_day
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'add_time'
),
single_creation as (
    select deal_id
    from creations
    group by deal_id
    having count(*) = 1
)
select
    count(*) filter (where changes.change_time::time <> creations.creation_time_of_day) as mismatches,
    count(*) as total_rows
from {{ source('pipedrive', 'deal_changes') }} as changes
inner join single_creation
    on changes.deal_id = single_creation.deal_id
inner join creations
    on changes.deal_id = creations.deal_id;

-- 3. ... and each of the 80 rows of the reused ids matches exactly ONE of its two creations,
--    which makes the split into two deals deterministic (implemented in int_deal_changes_resolved).
with creations as (
    select deal_id, change_time::time as creation_time_of_day
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'add_time'
),
reused as (
    select deal_id
    from creations
    group by deal_id
    having count(*) > 1
)
select
    n_matching_creations,
    count(*) as n_rows
from (
    select
        changes.deal_id,
        changes.change_time,
        changes.changed_field_key,
        count(creations.deal_id) as n_matching_creations
    from {{ source('pipedrive', 'deal_changes') }} as changes
    inner join reused
        on changes.deal_id = reused.deal_id
    left join creations
        on changes.deal_id = creations.deal_id
        and changes.change_time::time = creations.creation_time_of_day
    group by changes.deal_id, changes.change_time, changes.changed_field_key
) as matches
group by n_matching_creations;

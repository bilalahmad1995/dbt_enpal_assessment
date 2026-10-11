-- EDA 01 – deal change log (deal_changes)
-- Compile with `dbt compile --select eda_01_deal_changes` and run the statements in any SQL client.
-- Findings are summarised in README.md ("Exploratory analysis").

-- 1. Which fields are tracked, how often, over which period?
--    -> 4 fields: stage_id 8,906 | user_id 2,500 | add_time 2,000 | lost_reason 2,000 rows; 1,995 deal ids.
--    -> add_time 2024-01-01 .. 2024-09-13, stage / lost events run until 2025-03.
select
    changed_field_key,
    count(*) as n_rows,
    count(distinct deal_id) as n_deals,
    min(change_time) as first_change,
    max(change_time) as last_change
from {{ source('pipedrive', 'deal_changes') }}
group by changed_field_key
order by n_rows desc;

-- 2. Keys and nulls -> no nulls, no exact duplicates, (deal_id, field, change_time) is unique.
select
    count(*) as n_rows,
    count(*) - count(distinct (deal_id, change_time, changed_field_key)) as duplicate_keys,
    count(*) filter (where new_value is null) as null_values
from {{ source('pipedrive', 'deal_changes') }};

-- 3. add_time: value always equals change_time; 5 deal ids have TWO creations (see eda_02).
select
    creations_per_deal,
    count(*) as n_deal_ids
from (
    select deal_id, count(*) as creations_per_deal
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'add_time'
    group by deal_id
) as per_deal
group by creations_per_deal;

-- 4. Stage transitions -> every deal enters at stage 1; 36% of moves skip >= 1 stage;
--    backward / repeated moves only occur inside the 5 reused deal ids.
with stage_changes as (
    select
        deal_id,
        new_value::int as stage_id,
        lag(new_value::int) over (partition by deal_id order by change_time) as previous_stage_id
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'stage_id'
)
select
    case
        when previous_stage_id is null then 'pipeline_entry'
        when stage_id = previous_stage_id + 1 then 'next_stage'
        when stage_id > previous_stage_id + 1 then 'skipped_forward'
        when stage_id = previous_stage_id then 'repeated'
        else 'moved_backward'
    end as move_type,
    count(*) as n_moves
from stage_changes
group by 1
order by 1;

-- 5. lost_reason -> set exactly once on EVERY deal, 1–30 days after the last stage change, never
--    followed by another stage change (outside the reused ids). No won status exists in the extract,
--    even for deals that reached the post-sale stages 7-9.
with last_stage as (
    select deal_id, max(change_time) as last_stage_at
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'stage_id'
    group by deal_id
),
lost as (
    select deal_id, max(change_time) as lost_at
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'lost_reason'
    group by deal_id
)
select
    count(*) as lost_deals,
    min(lost.lost_at - last_stage.last_stage_at) as min_gap,
    max(lost.lost_at - last_stage.last_stage_at) as max_gap
from lost
inner join last_stage
    on lost.deal_id = last_stage.deal_id;

-- 6. Owners -> first assignment 1–30 days after creation, 0–2 re-assignments, all users exist.
select
    owner_changes,
    count(*) as n_deals
from (
    select deal_id, count(*) as owner_changes
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'user_id'
    group by deal_id
) as per_deal
group by owner_changes
order by owner_changes;

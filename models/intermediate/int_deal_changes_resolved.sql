-- Resolves reused deal ids into individual deals (deal_key).
--
-- Finding: 5 deal_ids carry two add_time events and two interleaved change histories, i.e. two
-- different deals share one id. In this extract every change of a deal is logged at the same
-- time of day as its creation (add_time), which assigns each row of a reused id to exactly one
-- creation. Ids with a single creation event are passed through untouched; the time-of-day rule
-- is only used to split the reused ids.
--
-- Guard rails (see yml): deal_change_id stays unique (no fan-out) and every row resolves to a
-- lifecycle. The root cause belongs upstream: Pipedrive deal ids are primary keys.

{{ config(materialized='table') }}  -- reused by every deal-level model downstream

with deal_changes as (

    select
        deal_change_id,
        deal_id,
        field_key,
        new_value,
        changed_at
    from {{ ref('stg_pipedrive__deal_changes') }}

),

deal_creations as (

    select
        deal_id,
        changed_at::time as creation_time_of_day,
        row_number() over (partition by deal_id order by changed_at) as deal_lifecycle_number,
        count(*) over (partition by deal_id) as creations_per_deal_id
    from deal_changes
    where field_key = 'add_time'

),

resolved as (

    select
        deal_changes.deal_change_id,
        deal_changes.deal_id,
        deal_creations.deal_lifecycle_number,
        coalesce(deal_creations.creations_per_deal_id > 1, false) as is_deal_id_reused,
        deal_changes.field_key,
        deal_changes.new_value,
        deal_changes.changed_at
    from deal_changes
    left join deal_creations
        on deal_changes.deal_id = deal_creations.deal_id
        and (
            deal_creations.creations_per_deal_id = 1
            or deal_creations.creation_time_of_day = deal_changes.changed_at::time
        )

)

select
    deal_change_id,
    case
        when is_deal_id_reused then deal_id::text || '-' || deal_lifecycle_number::text
        else deal_id::text
    end as deal_key,
    deal_id,
    deal_lifecycle_number,
    is_deal_id_reused,
    field_key,
    new_value,
    changed_at

from resolved

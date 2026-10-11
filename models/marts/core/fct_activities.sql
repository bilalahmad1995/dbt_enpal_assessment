-- One row per activity. Activities are kept even when their deal is missing from the deal
-- change log (true for almost all of them in this extract); has_deal_history makes that explicit.
-- The few id matches are consistent with chance (README finding 3): deal_key is an id match,
-- not a verified link, so do not use it to join activities to deal histories.

{{ config(indexes=[{'columns': ['deal_id']}]) }}

with activities as (

    select
        activity_key,
        activity_id,
        deal_id,
        user_id,
        activity_type_key,
        is_done,
        due_at
    from {{ ref('stg_pipedrive__activities') }}

),

activity_types as (

    select
        activity_type_key,
        activity_type_name,
        is_active
    from {{ ref('stg_pipedrive__activity_types') }}

),

-- one row per deal_id; deal_key only where the id maps to a single deal
deal_ids as (

    select
        deal_id,
        case when count(*) = 1 then min(deal_key) end as deal_key
    from {{ ref('dim_deals') }}
    group by deal_id

)

select
    activities.activity_key,
    activities.activity_id,
    activities.deal_id,
    deal_ids.deal_key,
    (deal_ids.deal_id is not null) as has_deal_history,
    activities.user_id,
    activities.activity_type_key,
    activity_types.activity_type_name,
    activity_types.is_active as is_activity_type_active,
    activities.is_done,
    activities.due_at,
    (count(*) over (partition by activities.activity_id) > 1) as is_activity_id_reused

from activities
left join activity_types
    on activities.activity_type_key = activity_types.activity_type_key
left join deal_ids
    on activities.deal_id = deal_ids.deal_id

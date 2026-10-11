-- EDA 03 – activities

-- 1. Keys -> 4,579 rows but 4,568 activity ids: 11 ids are reused by unrelated activities
--    (different deal, type, user and date), so activity_id is not a primary key.
select
    count(*) as n_rows,
    count(distinct activity_id) as n_activity_ids,
    count(*) - count(distinct (activity_id, type, assigned_to_user, deal_id, done, due_to)) as exact_duplicates
from {{ source('pipedrive', 'activity') }};

-- 2. Types x done -> 4 types, ~1.1k each, ~50% done. "Follow Up Call" is an inactive type
--    that still has historical activities. Sales Call 1 = type 'meeting', Sales Call 2 = 'sc_2'.
--    All types are due between 2024-01-01 and 2024-09-13: the activity extract ends on the day the
--    last deal was created, so Sep 2024 is a partial month for the sales-call steps.
select
    activity.type,
    activity_types.name,
    activity_types.active,
    count(*) as n_activities,
    count(*) filter (where activity.done) as n_done,
    count(distinct activity.deal_id) as n_deals,
    min(activity.due_to) as first_due,
    max(activity.due_to) as last_due
from {{ source('pipedrive', 'activity') }} as activity
left join {{ source('pipedrive', 'activity_types') }} as activity_types
    on activity.type = activity_types.type
group by activity.type, activity_types.name, activity_types.active
order by activity.type;

-- 3. Link to deals -> only 8 of 4,572 activity deal ids exist in deal_changes (a number
--    consistent with chance, see 5 and 6). Activities cannot be tied to pipeline stages in this extract;
--    sales-call KPIs are counted from activities alone.
select
    count(distinct activity.deal_id) as activity_deal_ids,
    count(distinct activity.deal_id) filter (where deals.deal_id is not null) as found_in_deal_changes
from {{ source('pipedrive', 'activity') }} as activity
left join (
    select distinct deal_id
    from {{ source('pipedrive', 'deal_changes') }}
) as deals
    on activity.deal_id = deals.deal_id;

-- 4. Granularity -> practically one activity per deal (one deal has two 'sc_2' rows).
select
    type,
    activities_per_deal,
    count(*) as n_deals
from (
    select deal_id, type, count(*) as activities_per_deal
    from {{ source('pipedrive', 'activity') }}
    group by deal_id, type
) as per_deal
group by type, activities_per_deal
order by type, activities_per_deal;

-- 5. Are the 8 matches (query 3) real links? -> Consistent with chance. Both id sets are 6-digit
--    numbers spread over 100000-999999, so about 4,572 x 1,995 / 900,000 = 10 ids would match at
--    random; 8 do.
select
    'activity' as source_table,
    count(distinct deal_id) as n_deal_ids,
    min(deal_id) as min_deal_id,
    max(deal_id) as max_deal_id
from {{ source('pipedrive', 'activity') }}
union all
select
    'deal_changes',
    count(distinct deal_id),
    min(deal_id),
    max(deal_id)
from {{ source('pipedrive', 'deal_changes') }};

-- 6. The matched activities -> 4 of the 8 are due before their deal was even created
--    (e.g. Sales Call 2 592431 is due 2024-04-19 on deal 984965, created 2024-08-29).
select
    activity.activity_id,
    activity.type,
    activity.done,
    activity.due_to,
    activity.deal_id,
    deals.created_at,
    activity.due_to < deals.created_at as is_due_before_deal_created
from {{ source('pipedrive', 'activity') }} as activity
inner join (
    select deal_id, min(change_time) as created_at
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'add_time'
    group by deal_id
) as deals
    on activity.deal_id = deals.deal_id
order by activity.due_to;

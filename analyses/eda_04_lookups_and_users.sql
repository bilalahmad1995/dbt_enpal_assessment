-- EDA 04 – lookups and users

-- 1. Stage names differ between the stages table and the fields metadata
--    -> stage 2 is 'Qualified lead' vs 'Qualified Lead'. KPI names are therefore owned by the
--       sales_funnel_steps seed rather than taken from either source.
select
    stages.stage_id,
    stages.stage_name,
    field_option ->> 'label' as field_option_label
from {{ source('pipedrive', 'stages') }} as stages
inner join {{ source('pipedrive', 'fields') }} as fields
    on fields.field_key = 'stage_id'
cross join lateral jsonb_array_elements(fields.field_value_options) as field_option
where (field_option ->> 'id')::int = stages.stage_id
    and stages.stage_name <> field_option ->> 'label';

-- 2. Enum options available for decoding (stage_id, lost_reason).
select
    fields.field_key,
    (field_option ->> 'id')::int as option_id,
    field_option ->> 'label' as option_label
from {{ source('pipedrive', 'fields') }} as fields
cross join lateral jsonb_array_elements(fields.field_value_options) as field_option
order by fields.field_key, option_id;

-- 3. Users -> 1,787 unique ids; names/emails are not unique (synthetic data), every deal owner
--    and activity assignee exists. Personal data: kept in staging, only names reach the marts.
select
    count(*) as n_users,
    count(distinct id) as n_ids,
    count(distinct name) as n_names,
    count(distinct email) as n_emails,
    min(modified) as first_modified,
    max(modified) as last_modified
from {{ source('pipedrive', 'users') }};

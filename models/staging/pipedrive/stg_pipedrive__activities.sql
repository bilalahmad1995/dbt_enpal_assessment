-- activity_id is not unique in the source (11 ids reused by unrelated activities), so a
-- surrogate key over the full natural record is the primary key.

select
    {{ dbt_utils.generate_surrogate_key(['activity_id', 'deal_id', 'type', 'due_to']) }} as activity_key,
    activity_id,
    deal_id,
    assigned_to_user as user_id,
    type as activity_type_key,
    done as is_done,
    due_to as due_at

from {{ source('pipedrive', 'activity') }}

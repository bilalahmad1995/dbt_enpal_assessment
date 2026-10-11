-- Deal owner assignments as validity intervals [valid_from, valid_to), enabling as-of joins
-- ("who owned the deal when X happened"). A deal has no owner before its first assignment.

with owner_changes as (

    select
        deal_change_id,
        deal_key,
        deal_id,
        new_value::int as user_id,
        changed_at as valid_from
    from {{ ref('int_deal_changes_resolved') }}
    where field_key = 'user_id'

)

select
    deal_change_id as deal_owner_change_id,
    deal_key,
    deal_id,
    user_id,
    row_number() over deal_timeline as owner_sequence_number,
    valid_from,
    lead(valid_from) over deal_timeline as valid_to,
    (lead(valid_from) over deal_timeline is null) as is_current_owner

from owner_changes
window deal_timeline as (partition by deal_key order by valid_from, deal_change_id)

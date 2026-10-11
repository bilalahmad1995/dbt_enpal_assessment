-- Deal change log, kept in its native long (EAV) shape: new_value stays text because its
-- type depends on field_key. Typed, field-specific views are built in the intermediate layer.

select
    {{ dbt_utils.generate_surrogate_key(['deal_id', 'change_time', 'changed_field_key']) }} as deal_change_id,
    deal_id,
    changed_field_key as field_key,
    new_value,
    change_time as changed_at

from {{ source('pipedrive', 'deal_changes') }}

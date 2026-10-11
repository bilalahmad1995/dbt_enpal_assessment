-- Flattens the JSON option list of enum fields (stage_id, lost_reason) to one row per option,
-- so enum ids in deal_changes can be decoded with a plain join.

select
    fields.field_key,
    (field_option ->> 'id')::int as option_id,
    field_option ->> 'label' as option_label

from {{ source('pipedrive', 'fields') }} as fields
cross join lateral jsonb_array_elements(fields.field_value_options) as field_option

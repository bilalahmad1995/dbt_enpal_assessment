select
    id as field_id,
    field_key,
    name as field_name,
    (field_value_options is not null) as has_value_options

from {{ source('pipedrive', 'fields') }}

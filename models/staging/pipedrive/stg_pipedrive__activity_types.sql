select
    id as activity_type_id,
    type as activity_type_key,
    name as activity_type_name,
    (active = 'Yes') as is_active

from {{ source('pipedrive', 'activity_types') }}

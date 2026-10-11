select
    stage_id,
    stage_name

from {{ source('pipedrive', 'stages') }}

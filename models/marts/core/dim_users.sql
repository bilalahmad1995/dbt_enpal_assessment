-- Pipedrive users (deal owners, activity assignees). Email is deliberately not exposed in marts.

select
    user_id,
    user_name,
    modified_at

from {{ ref('stg_pipedrive__users') }}

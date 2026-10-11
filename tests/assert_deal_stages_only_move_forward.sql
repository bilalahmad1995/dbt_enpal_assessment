-- After lifecycle resolution, deals in this extract only ever move forward through the pipeline
-- (EDA: every backward / repeated move sat in a reused deal id). New backward or repeated moves
-- are legal in Pipedrive but worth knowing about, so this is a warning, not an error.

{{ config(severity='warn') }}

select
    deal_stage_change_id,
    deal_key,
    previous_stage_id,
    stage_id,
    stage_move_type
from {{ ref('int_deal_stage_changes') }}
where stage_move_type in ('moved_backward', 'repeated')

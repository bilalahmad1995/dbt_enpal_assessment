-- One row per stage change of a deal, with its position in the deal's stage timeline.
-- The timeline functions (row_number, lag, lead) share one named window, so they need one sort;
-- only is_first_entry_to_stage needs its own partition (deal_key, stage_id).

with stage_changes as (

    select
        deal_change_id,
        deal_key,
        deal_id,
        new_value::int as stage_id,
        changed_at as entered_at
    from {{ ref('int_deal_changes_resolved') }}
    where field_key = 'stage_id'

),

sequenced as (

    select
        deal_change_id,
        deal_key,
        deal_id,
        stage_id,
        entered_at,
        row_number() over deal_timeline as stage_sequence_number,
        lag(stage_id) over deal_timeline as previous_stage_id,
        lead(entered_at) over deal_timeline as exited_at,
        row_number() over (
            partition by deal_key, stage_id
            order by entered_at, deal_change_id
        ) = 1 as is_first_entry_to_stage
    from stage_changes
    window deal_timeline as (partition by deal_key order by entered_at, deal_change_id)

)

select
    deal_change_id as deal_stage_change_id,
    deal_key,
    deal_id,
    stage_id,
    stage_sequence_number,
    previous_stage_id,
    case
        when previous_stage_id is null then 'pipeline_entry'
        when stage_id = previous_stage_id + 1 then 'next_stage'
        when stage_id > previous_stage_id + 1 then 'skipped_forward'
        when stage_id = previous_stage_id then 'repeated'
        else 'moved_backward'
    end as stage_move_type,
    greatest(stage_id - coalesce(previous_stage_id, 0) - 1, 0) as stages_skipped,
    is_first_entry_to_stage,
    (exited_at is null) as is_current_stage,
    entered_at,
    exited_at

from sequenced

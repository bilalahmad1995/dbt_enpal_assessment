-- Deal stage history: one row per stage a deal entered, with the time until its next stage change
-- and who owned the deal at that moment. Serves conversion, stage-transition time, skip-rate and
-- owner-level funnel KPIs. A deal's last stage has no exit (for lost deals: the stage they were
-- lost from), so days_in_stage is null there; time to loss lives in dim_deals.lost_at.

{{
    config(
        indexes=[
            {'columns': ['deal_key']},
            {'columns': ['stage_id', 'entered_at']},
        ]
    )
}}

with stage_changes as (

    select
        deal_stage_change_id,
        deal_key,
        deal_id,
        stage_id,
        stage_sequence_number,
        previous_stage_id,
        stage_move_type,
        stages_skipped,
        is_first_entry_to_stage,
        is_current_stage,
        entered_at,
        exited_at
    from {{ ref('int_deal_stage_changes') }}

),

stages as (

    select
        stage_id,
        stage_name
    from {{ ref('stg_pipedrive__stages') }}

),

owner_history as (

    select
        deal_key,
        user_id,
        valid_from,
        valid_to
    from {{ ref('int_deal_owner_history') }}

)

select
    stage_changes.deal_stage_change_id,
    stage_changes.deal_key,
    stage_changes.deal_id,
    stage_changes.stage_id,
    stages.stage_name,
    stage_changes.stage_sequence_number,
    stage_changes.previous_stage_id,
    stage_changes.stage_move_type,
    stage_changes.stages_skipped,
    stage_changes.is_first_entry_to_stage,
    stage_changes.is_current_stage,
    owner_history.user_id as owner_user_id,
    stage_changes.entered_at,
    stage_changes.exited_at,
    round(extract(epoch from stage_changes.exited_at - stage_changes.entered_at) / 86400, 2) as days_in_stage

from stage_changes
left join stages
    on stage_changes.stage_id = stages.stage_id
-- as-of join: the owner whose validity interval contains the stage entry
left join owner_history
    on stage_changes.deal_key = owner_history.deal_key
    and stage_changes.entered_at >= owner_history.valid_from
    and (stage_changes.entered_at < owner_history.valid_to or owner_history.valid_to is null)

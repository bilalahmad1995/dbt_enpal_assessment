-- One row per deal with its current state, which Pipedrive's change log never stores directly.

{{
    config(
        indexes=[
            {'columns': ['deal_key'], 'unique': True},
            {'columns': ['deal_id']},
        ]
    )
}}

with deal_changes as (

    select
        deal_key,
        deal_id,
        deal_lifecycle_number,
        is_deal_id_reused,
        field_key,
        new_value,
        changed_at
    from {{ ref('int_deal_changes_resolved') }}

),

stage_changes as (

    select
        deal_key,
        stage_id,
        stages_skipped,
        is_current_stage,
        entered_at
    from {{ ref('int_deal_stage_changes') }}

),

owner_history as (

    select
        deal_key,
        user_id,
        is_current_owner
    from {{ ref('int_deal_owner_history') }}

),

stages as (

    select
        stage_id,
        stage_name
    from {{ ref('stg_pipedrive__stages') }}

),

lost_reasons as (

    select
        option_id as lost_reason_id,
        option_label as lost_reason
    from {{ ref('stg_pipedrive__field_options') }}
    where field_key = 'lost_reason'

),

-- single pass over the change log for all timestamp attributes
deal_timeline as (

    select
        deal_key,
        min(deal_id) as deal_id,
        min(deal_lifecycle_number) as deal_lifecycle_number,
        bool_or(is_deal_id_reused) as is_deal_id_reused,
        min(changed_at) filter (where field_key = 'add_time') as created_at,
        max(changed_at) filter (where field_key = 'lost_reason') as lost_at,
        max(changed_at) as last_changed_at
    from deal_changes
    group by deal_key

),

latest_lost_reason as (

    select distinct on (deal_key)
        deal_key,
        new_value::int as lost_reason_id
    from deal_changes
    where field_key = 'lost_reason'
    order by deal_key, changed_at desc

),

stage_summary as (

    select
        deal_key,
        max(stage_id) filter (where is_current_stage) as current_stage_id,
        max(stage_id) as max_stage_id,
        min(entered_at) as pipeline_entered_at,
        max(entered_at) as current_stage_entered_at,
        count(*) as stage_change_count,
        sum(stages_skipped) as stages_skipped_count
    from stage_changes
    group by deal_key

),

owner_summary as (

    select
        deal_key,
        max(user_id) filter (where is_current_owner) as current_owner_user_id,
        count(*) as owner_assignment_count
    from owner_history
    group by deal_key

)

select
    deal_timeline.deal_key,
    deal_timeline.deal_id,
    deal_timeline.deal_lifecycle_number,
    deal_timeline.is_deal_id_reused,
    case when deal_timeline.lost_at is not null then 'lost' else 'open' end as deal_status,
    stage_summary.current_stage_id,
    current_stage.stage_name as current_stage_name,
    stage_summary.max_stage_id,
    max_stage.stage_name as max_stage_name,
    owner_summary.current_owner_user_id,
    latest_lost_reason.lost_reason_id,
    lost_reasons.lost_reason,
    deal_timeline.created_at,
    stage_summary.pipeline_entered_at,
    stage_summary.current_stage_entered_at,
    deal_timeline.lost_at,
    deal_timeline.last_changed_at,
    coalesce(stage_summary.stage_change_count, 0) as stage_change_count,
    coalesce(stage_summary.stages_skipped_count, 0) as stages_skipped_count,
    coalesce(owner_summary.owner_assignment_count, 0) as owner_assignment_count

from deal_timeline
left join stage_summary
    on deal_timeline.deal_key = stage_summary.deal_key
left join owner_summary
    on deal_timeline.deal_key = owner_summary.deal_key
left join latest_lost_reason
    on deal_timeline.deal_key = latest_lost_reason.deal_key
left join stages as current_stage
    on stage_summary.current_stage_id = current_stage.stage_id
left join stages as max_stage
    on stage_summary.max_stage_id = max_stage.stage_id
left join lost_reasons
    on latest_lost_reason.lost_reason_id = lost_reasons.lost_reason_id

-- The moment each deal entered each funnel step: one row per (deal, funnel step).
-- Which event counts for which step comes from the sales_funnel_steps seed:
--   * pipeline stages  -> the deal's first move into that stage
--   * sales-call steps -> the deal's first completed (is_done) activity of that type
-- Reusable for monthly entries of every step. Cohort conversion and time between steps work for the
-- stage steps only: sales-call deals cannot be linked to the deal change log (README finding 3).

{{ config(indexes=[{'columns': ['funnel_step', 'entered_month']}]) }}

with funnel_steps as (

    select
        funnel_step,
        kpi_name,
        source_type,
        pipedrive_stage_id,
        pipedrive_activity_type
    from {{ ref('sales_funnel_steps') }}

),

first_stage_entries as (

    select
        deal_key,
        deal_id,
        stage_id,
        entered_at
    from {{ ref('fct_deal_stage_history') }}
    where is_first_entry_to_stage

),

first_completed_activities as (

    -- activity deals are mostly absent from the change log: fall back to the plain deal_id,
    -- which is exactly the deal_key format of a non-reused deal. For sales-call rows deal_key is
    -- therefore the activity's deal_id and practically never matches a row in dim_deals.
    select
        coalesce(deal_key, deal_id::text) as deal_key,
        deal_id,
        activity_type_key,
        min(due_at) as entered_at
    from {{ ref('fct_activities') }}
    where is_done
    group by coalesce(deal_key, deal_id::text), deal_id, activity_type_key

),

funnel_events as (

    select
        funnel_steps.funnel_step,
        funnel_steps.kpi_name,
        funnel_steps.source_type,
        first_stage_entries.deal_key,
        first_stage_entries.deal_id,
        first_stage_entries.entered_at
    from first_stage_entries
    inner join funnel_steps
        on first_stage_entries.stage_id = funnel_steps.pipedrive_stage_id

    union all

    select
        funnel_steps.funnel_step,
        funnel_steps.kpi_name,
        funnel_steps.source_type,
        first_completed_activities.deal_key,
        first_completed_activities.deal_id,
        first_completed_activities.entered_at
    from first_completed_activities
    inner join funnel_steps
        on first_completed_activities.activity_type_key = funnel_steps.pipedrive_activity_type

)

select
    {{ dbt_utils.generate_surrogate_key(['deal_key', 'funnel_step']) }} as funnel_event_id,
    deal_key,
    deal_id,
    funnel_step,
    kpi_name,
    source_type as event_source,
    entered_at,
    date_trunc('month', entered_at)::date as entered_month

from funnel_events

-- End-to-end reconciliation at the report's grain (month x funnel step). The expected report is
-- rebuilt independently from the layers below the marts and compared row by row with the real one:
--   * stage steps    -> each deal's first change into the stage (resolved change log)
--   * activity steps -> each deal's first completed activity of the type (staging)
-- Fails on a wrong count, an entry booked in the wrong month, a missing row (including the
-- zero-filled ones) or an unexpected extra row.

with funnel_steps as (

    select
        funnel_step,
        pipedrive_stage_id,
        pipedrive_activity_type
    from {{ ref('sales_funnel_steps') }}

),

first_stage_entries as (

    select
        deal_key,
        new_value::int as stage_id,
        date_trunc('month', min(changed_at))::date as entered_month
    from {{ ref('int_deal_changes_resolved') }}
    where field_key = 'stage_id'
    group by deal_key, new_value::int

),

first_completed_activities as (

    select
        deal_id,
        activity_type_key,
        date_trunc('month', min(due_at))::date as entered_month
    from {{ ref('stg_pipedrive__activities') }}
    where is_done
    group by deal_id, activity_type_key

),

expected_entries as (

    select
        funnel_steps.funnel_step,
        first_stage_entries.entered_month
    from first_stage_entries
    inner join funnel_steps
        on first_stage_entries.stage_id = funnel_steps.pipedrive_stage_id

    union all

    select
        funnel_steps.funnel_step,
        first_completed_activities.entered_month
    from first_completed_activities
    inner join funnel_steps
        on first_completed_activities.activity_type_key = funnel_steps.pipedrive_activity_type

),

expected_counts as (

    select
        entered_month as month,
        funnel_step,
        count(*) as deals_count
    from expected_entries
    group by entered_month, funnel_step

),

-- the report is dense: every month from the first to the last entry x every funnel step
expected_report as (

    select
        months.month,
        funnel_steps.funnel_step,
        coalesce(expected_counts.deals_count, 0) as deals_count
    from (
        select month_start::date as month
        from (
            select
                min(entered_month) as first_month,
                max(entered_month) as last_month
            from expected_entries
        ) as bounds
        cross join lateral generate_series(
            bounds.first_month::timestamp,
            bounds.last_month::timestamp,
            interval '1 month'
        ) as month_start
    ) as months
    cross join funnel_steps
    left join expected_counts
        on months.month = expected_counts.month
        and funnel_steps.funnel_step = expected_counts.funnel_step

),

report as (

    select
        month,
        funnel_step,
        deals_count
    from {{ ref('rep_sales_funnel_monthly') }}

)

select
    coalesce(expected_report.month, report.month) as month,
    coalesce(expected_report.funnel_step, report.funnel_step) as funnel_step,
    expected_report.deals_count as expected_deals,
    report.deals_count as report_deals,
    case
        when report.month is null then 'missing from report'
        when expected_report.month is null then 'unexpected row in report'
        else 'count mismatch'
    end as issue
from expected_report
full outer join report
    on expected_report.month = report.month
    and expected_report.funnel_step = report.funnel_step
where expected_report.deals_count is distinct from report.deals_count

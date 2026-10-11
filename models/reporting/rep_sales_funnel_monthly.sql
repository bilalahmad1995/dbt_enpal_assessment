-- Monthly sales funnel: how many deals entered each funnel step per month.
-- Dense output: every month x every step, with 0 where no deal entered, so month-over-month
-- comparisons and charts never miss rows.

with funnel_steps as (

    select
        funnel_step,
        kpi_name
    from {{ ref('sales_funnel_steps') }}

),

funnel_events as (

    select
        funnel_step,
        entered_month
    from {{ ref('fct_sales_funnel_events') }}

),

months as (

    select month_start::date as month
    from (
        select
            min(entered_month) as first_month,
            max(entered_month) as last_month
        from funnel_events
    ) as bounds
    cross join lateral generate_series(
        bounds.first_month::timestamp,
        bounds.last_month::timestamp,
        interval '1 month'
    ) as month_start

),

monthly_entries as (

    -- fct_sales_funnel_events is unique per (deal, step), so count(*) already counts distinct deals
    select
        entered_month as month,
        funnel_step,
        count(*) as deals_count
    from funnel_events
    group by entered_month, funnel_step

)

select
    months.month,
    funnel_steps.kpi_name,
    funnel_steps.funnel_step,
    coalesce(monthly_entries.deals_count, 0)::integer as deals_count

from months
cross join funnel_steps
left join monthly_entries
    on months.month = monthly_entries.month
    and funnel_steps.funnel_step = monthly_entries.funnel_step

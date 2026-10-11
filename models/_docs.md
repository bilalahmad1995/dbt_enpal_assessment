{% docs __overview__ %}
# Enpal – Pipedrive sales analytics

dbt project modelling a Pipedrive CRM extract into reusable deal / activity data layers and a
monthly sales funnel report (`rep_sales_funnel_monthly`).

Data flow: `sources (public)` → `staging` → `intermediate` → `marts` → `reporting`.
See the repository README for the data findings, modelling decisions and KPI definitions.
{% enddocs %}

{% docs deal_id %}
Pipedrive deal id as delivered by the source. **Not unique per deal in this extract**: 5 ids are
shared by two independent deals (two `add_time` events, interleaved histories). Use `deal_key`
as the deal identifier and keep `deal_id` for lookups against Pipedrive.
{% enddocs %}

{% docs deal_key %}
Unique deal identifier used across all marts. Equals `deal_id` for the normal case; for the 5
deal ids reused by two deals it is suffixed with the lifecycle number (e.g. `399956-2`).
See `int_deal_changes_resolved`.
{% enddocs %}

{% docs deal_lifecycle_number %}
1 for normal deals. For a reused `deal_id`, the 1-based order of the deal's creation (`add_time`)
among the deals sharing that id.
{% enddocs %}

{% docs stage_id %}
Pipedrive pipeline stage id (1 = Lead Generation … 9 = Renewal/Expansion). The pipeline has a
single, linearly ordered set of stages, so the id doubles as the stage order.
{% enddocs %}

{% docs funnel_step %}
Funnel step number as defined in the `sales_funnel_steps` seed: 1–9 for pipeline stages, 2.1 and
3.1 for the sales-call sub-steps. Numeric, so it sorts in funnel order.
{% enddocs %}

{% docs kpi_name %}
Business name of the funnel step / KPI (e.g. `Qualified Lead`, `Sales Call 1`), maintained in the
`sales_funnel_steps` seed.
{% enddocs %}

{% docs stage_sequence_number %}
Position of the stage change in the deal's timeline: 1 for the pipeline entry, then incrementing.
{% enddocs %}

{% docs previous_stage_id %}
Stage the deal came from; null for the pipeline entry.
{% enddocs %}

{% docs stage_move_type %}
Kind of stage move: `pipeline_entry`, `next_stage`, `skipped_forward`, `repeated` or `moved_backward`.
{% enddocs %}

{% docs stages_skipped %}
Number of stages jumped over by this move (0 for a move to the next stage and for an entry at stage 1).
{% enddocs %}

{% docs is_first_entry_to_stage %}
True for the first time the deal entered this stage; re-entries are false. Basis of the "deal entered
funnel step" KPIs.
{% enddocs %}

{% docs stage_entered_at %}
When the deal entered the stage (time of the `stage_id` change in the change log).
{% enddocs %}

{% docs activity_type_key %}
Machine key of the activity type (`meeting` = Sales Call 1, `sc_2` = Sales Call 2, `follow_up`,
`after_close_call`). The `sales_funnel_steps` seed maps steps 2.1 and 3.1 to these keys.
{% enddocs %}

{% docs is_done %}
True if the activity was marked as done. Only done activities count as sales calls in the funnel.
{% enddocs %}

-- Grain: 1 row per flag per level.
-- Account level for all 12 flags; transaction level for the 6 Phase 1 rules.
-- precision = share of flagged items that are illicit; recall = share of illicit items flagged;
-- lift = precision divided by the base illicit rate at that level.
{% set account_flags = ['structuring_band', 'structuring_24h', 'pass_through', 'high_velocity', 'round_amount', 'cross_currency',
                        'fan_out', 'fan_in', 'gather_scatter', 'cycle_2', 'cycle_3', 'scatter_gather'] %}
{% set txn_flags = ['structuring_band', 'structuring_24h', 'pass_through', 'high_velocity', 'round_amount', 'cross_currency'] %}

with account_base as (
    select count(*) as n, sum(case when is_laundering_account then 1 else 0 end) as n_pos
    from {{ ref('sc_account_risk') }}
),

txn_base as (
    select count(*) as n, sum(is_laundering) as n_pos
    from {{ ref('det_transaction_flags') }}
),

account_level as (
    {% for f in account_flags %}
    select 'account' as level, '{{ f }}' as flag_name,
           sum(f_{{ f }}) as flagged,
           sum(case when f_{{ f }} = 1 and is_laundering_account then 1 else 0 end) as tp
    from {{ ref('sc_account_risk') }}
    {{ "union all" if not loop.last }}
    {% endfor %}
),

txn_level as (
    {% for f in txn_flags %}
    select 'transaction' as level, '{{ f }}' as flag_name,
           sum(case when flag_{{ f }} then 1 else 0 end) as flagged,
           sum(case when flag_{{ f }} and is_laundering = 1 then 1 else 0 end) as tp
    from {{ ref('det_transaction_flags') }}
    {{ "union all" if not loop.last }}
    {% endfor %}
)

select
    a.level, a.flag_name, a.flagged, a.tp,
    a.flagged / b.n                                         as flag_rate,
    case when a.flagged > 0 then a.tp / a.flagged end       as precision,
    a.tp / b.n_pos                                          as recall,
    case when a.flagged > 0 then (a.tp / a.flagged) / (b.n_pos / b.n) end as lift_over_base_rate
from account_level a cross join account_base b
union all
select
    t.level, t.flag_name, t.flagged, t.tp,
    t.flagged / b.n,
    case when t.flagged > 0 then t.tp / t.flagged end,
    t.tp / b.n_pos,
    case when t.flagged > 0 then (t.tp / t.flagged) / (b.n_pos / b.n) end
from txn_level t cross join txn_base b

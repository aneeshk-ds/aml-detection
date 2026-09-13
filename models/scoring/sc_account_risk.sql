-- Grain: 1 row per active account (sent or received at least 1 payment in int_edges).
-- One 0/1 column per rule and typology, a weighted risk_score, and a rank.
-- Weights come from dbt_project.yml vars; rationale is in writeup/methodology.md.
-- is_laundering_account is attached for evaluation only and is not used in the score or rank.
with accounts as (
    select from_account_key as account_key from {{ ref('int_edges') }}
    union
    select to_account_key from {{ ref('int_edges') }}
),

activity as (
    select account_key,
           sum(n_out) as n_txns_out, sum(n_in) as n_txns_in,
           sum(usd_out) as usd_out, sum(usd_in) as usd_in,
           max(illicit) as is_laundering_account
    from (
        select from_account_key as account_key, 1 as n_out, 0 as n_in, amount_paid_usd as usd_out, 0.0 as usd_in, is_laundering as illicit
        from {{ ref('int_edges') }}
        union all
        select to_account_key, 0, 1, 0.0, amount_received_usd, is_laundering
        from {{ ref('int_edges') }}
    )
    group by account_key
),

flagged as (
    select 'structuring_band' as flag_name, from_account_key as account_key from {{ ref('det_structuring_band') }}
    union select 'structuring_24h', from_account_key from {{ ref('det_structuring_24h') }}
    union select 'pass_through',    from_account_key from {{ ref('det_pass_through') }}
    union select 'high_velocity',   from_account_key from {{ ref('det_high_velocity') }}
    union select 'round_amount',    from_account_key from {{ ref('det_round_amount') }}
    union select 'cross_currency',  from_account_key from {{ ref('det_cross_currency') }}
    union select 'fan_out',         account_key      from {{ ref('gr_fan_out') }}
    union select 'fan_in',          account_key      from {{ ref('gr_fan_in') }}
    union select 'gather_scatter',  account_key      from {{ ref('gr_gather_scatter') }}
    union select 'cycle_2',         account_a        from {{ ref('gr_cycle_2') }}
    union select 'cycle_2',         account_b        from {{ ref('gr_cycle_2') }}
    union select 'cycle_3',         account_a        from {{ ref('gr_cycle_3') }}
    union select 'cycle_3',         account_b        from {{ ref('gr_cycle_3') }}
    union select 'cycle_3',         account_c        from {{ ref('gr_cycle_3') }}
    union select 'scatter_gather',  source_key       from {{ ref('gr_scatter_gather') }}
    union select 'scatter_gather',  sink_key         from {{ ref('gr_scatter_gather') }}
    union select 'scatter_gather',  intermediary_key from {{ ref('gr_scatter_gather') }}
),

{% set flags = ['structuring_band', 'structuring_24h', 'pass_through', 'high_velocity', 'round_amount', 'cross_currency',
                'fan_out', 'fan_in', 'gather_scatter', 'cycle_2', 'cycle_3', 'scatter_gather'] %}

flag_matrix as (
    select
        account_key,
        {% for f in flags %}
        max(case when flag_name = '{{ f }}' then 1 else 0 end) as f_{{ f }}{{ "," if not loop.last }}
        {% endfor %}
    from flagged
    group by account_key
),

scored as (
    select
        a.account_key,
        {% for f in flags %}
        coalesce(m.f_{{ f }}, 0) as f_{{ f }},
        {% endfor %}
        (
        {% for f in flags %}
            {{ var('weight_' ~ f) }} * coalesce(m.f_{{ f }}, 0){{ " +" if not loop.last }}
        {% endfor %}
        ) as risk_score,
        (
        {% for f in flags %}
            coalesce(m.f_{{ f }}, 0){{ " +" if not loop.last }}
        {% endfor %}
        ) as n_flag_types
    from accounts a
    left join flag_matrix m using (account_key)
)

select
    row_number() over (
        order by s.risk_score desc, s.n_flag_types desc, act.usd_out + act.usd_in desc, s.account_key
    )                                   as risk_rank,
    s.*,
    act.n_txns_out,
    act.n_txns_in,
    act.usd_out,
    act.usd_in,
    act.is_laundering_account = 1       as is_laundering_account
from scored s
join activity act using (account_key)

-- Grain: 1 row per alerted account per piece of evidence.
--
-- This is the file an investigator opens when an account reaches the queue. A rank and a score
-- say an account is suspicious; they do not say why, or what to look at. This model answers both.
--
-- The laundering label is deliberately absent. This is the alert exactly as an analyst sees it,
-- the same convention sc_top100 follows.
--
-- The alert set comes from the cutoff the evaluation layer chooses rather than a hard-coded 6,
-- so the evidence always describes exactly the accounts the reported metrics describe. The
-- holdout (outputs/holdout.md) argues for pinning that cutoff explicitly; until it is pinned,
-- deriving it here keeps the two in step.
--
-- Transaction evidence is capped at evidence_txn_cap payments per rule per account. A busy
-- account otherwise produces thousands of rows and the case file stops being readable.
{{ config(materialized = 'table') }}

{% set flags = ['structuring_band', 'structuring_24h', 'pass_through', 'high_velocity', 'round_amount', 'cross_currency',
                'fan_out', 'fan_in', 'gather_scatter', 'cycle_2', 'cycle_3', 'scatter_gather'] %}
{% set rules = ['round_amount', 'cross_currency', 'structuring_band', 'structuring_24h', 'high_velocity', 'pass_through'] %}
{% set txn_cap = 20 %}

with chosen as (
    select cutoff from {{ ref('ev_cutoff_curve') }} where is_chosen_cutoff
),

alerted as (
    select r.account_key, r.risk_rank, r.risk_score, r.n_txns_out, r.n_txns_in, r.usd_out, r.usd_in
    from {{ ref('sc_account_risk') }} r
    cross join chosen c
    where r.risk_score >= c.cutoff
),

-- 1. Why the score is what it is: one row per flag that fired, with the weight it contributed.
score_evidence as (
    {% for f in flags %}
    select
        a.account_key,
        'score'                                 as evidence_class,
        '{{ f }}'                               as evidence_type,
        cast(null as varchar)                   as txn_id,
        cast(null as timestamp)                 as event_ts,
        cast(null as double)                    as amount_usd,
        cast(null as varchar)                   as counterparty,
        'contributed {{ var("weight_" ~ f) }} to the score' as detail
    from alerted a
    join {{ ref('sc_account_risk') }} s using (account_key)
    where s.f_{{ f }} = 1
    {{ "union all" if not loop.last }}
    {% endfor %}
),

-- 2. The payments that tripped each transaction-level rule.
rule_hits as (
    {% for r in rules %}
    select '{{ r }}' as evidence_type, txn_id, from_account_key as account_key
    from {{ ref('det_' ~ r) }}
    {{ "union all" if not loop.last }}
    {% endfor %}
),

ranked_txns as (
    select
        h.account_key,
        h.evidence_type,
        e.txn_id,
        e.txn_ts,
        e.amount_paid_usd,
        e.to_account_key,
        e.payment_format,
        row_number() over (
            partition by h.account_key, h.evidence_type
            order by e.amount_paid_usd desc, e.txn_id
        ) as rn
    from rule_hits h
    join alerted a on a.account_key = h.account_key
    join {{ ref('int_edges') }} e on e.txn_id = h.txn_id
),

txn_evidence as (
    select
        account_key,
        'transaction'                as evidence_class,
        evidence_type,
        cast(txn_id as varchar)      as txn_id,
        txn_ts                       as event_ts,
        amount_paid_usd              as amount_usd,
        to_account_key               as counterparty,
        'paid via ' || payment_format as detail
    from ranked_txns
    where rn <= {{ txn_cap }}
),

-- 3. The account's role in each network typology, and who sits on the other side.
network_raw as (
    select account_key, 'fan_out' as evidence_type, detect_ts as event_ts,
           cast(null as double) as amount_usd, cast(null as varchar) as counterparty,
           'sent to ' || cast(new_counterparties_window as varchar) || ' new counterparties inside 72h' as detail
    from {{ ref('gr_fan_out') }}
    union all
    select account_key, 'fan_in', detect_ts,
           cast(null as double), cast(null as varchar),
           'received from ' || cast(new_counterparties_window as varchar) || ' new counterparties inside 72h'
    from {{ ref('gr_fan_in') }}
    union all
    select account_key, 'gather_scatter', first_gather_ts,
           cast(null as double), cast(null as varchar),
           'fan-in followed by fan-out within 72h, ' || cast(n_gather_events_followed_by_scatter as varchar) || ' times'
    from {{ ref('gr_gather_scatter') }}
    union all
    select account_a, 'cycle_2', cycle_start_ts, usd_paid, account_b,
           'reciprocal pair, ' || cast(n_txns as varchar) || ' payments both ways'
    from {{ ref('gr_cycle_2') }}
    union all
    select account_b, 'cycle_2', cycle_start_ts, usd_paid, account_a,
           'reciprocal pair, ' || cast(n_txns as varchar) || ' payments both ways'
    from {{ ref('gr_cycle_2') }}
    union all
    select account_a, 'cycle_3', cycle_start_ts, usd_paid, account_b,
           'closed 3-account loop, pays ' || account_b || ' which reaches ' || account_c
    from {{ ref('gr_cycle_3') }}
    union all
    select account_b, 'cycle_3', cycle_start_ts, usd_paid, account_c,
           'closed 3-account loop, pays ' || account_c || ' which reaches ' || account_a
    from {{ ref('gr_cycle_3') }}
    union all
    select account_c, 'cycle_3', cycle_start_ts, usd_paid, account_a,
           'closed 3-account loop, pays ' || account_a || ' which reaches ' || account_b
    from {{ ref('gr_cycle_3') }}
    union all
    select source_key, 'scatter_gather', min(start_ts), cast(null as double), sink_key,
           'source of a route reaching this sink through ' || cast(max(n_intermediaries) as varchar) || ' intermediaries'
    from {{ ref('gr_scatter_gather') }} group by source_key, sink_key
    union all
    select sink_key, 'scatter_gather', min(start_ts), cast(null as double), source_key,
           'sink of a route from this source through ' || cast(max(n_intermediaries) as varchar) || ' intermediaries'
    from {{ ref('gr_scatter_gather') }} group by sink_key, source_key
    union all
    select intermediary_key, 'scatter_gather', min(start_ts), cast(null as double), source_key,
           'intermediary carrying funds from this source to ' || sink_key
    from {{ ref('gr_scatter_gather') }} group by intermediary_key, source_key, sink_key
),

network_ranked as (
    select n.*,
           row_number() over (partition by n.account_key, n.evidence_type order by n.event_ts) as rn
    from network_raw n
    join alerted a on a.account_key = n.account_key
),

network_evidence as (
    select account_key, 'network' as evidence_class, evidence_type,
           cast(null as varchar) as txn_id, event_ts, amount_usd, counterparty, detail
    from network_ranked
    where rn <= {{ txn_cap }}
),

-- 4. Context an analyst needs to judge whether the volume above is unusual for this account.
profile_evidence as (
    select
        a.account_key,
        'profile'                as evidence_class,
        'activity'               as evidence_type,
        cast(null as varchar)    as txn_id,
        cast(null as timestamp)  as event_ts,
        a.usd_out + a.usd_in     as amount_usd,
        cast(null as varchar)    as counterparty,
        cast(a.n_txns_out as varchar) || ' sent, ' || cast(a.n_txns_in as varchar) || ' received' as detail
    from alerted a
),

all_evidence as (
    select * from score_evidence
    union all select * from txn_evidence
    union all select * from network_evidence
    union all select * from profile_evidence
)

select
    a.risk_rank,
    a.risk_score,
    e.account_key,
    e.evidence_class,
    e.evidence_type,
    e.txn_id,
    e.event_ts,
    round(e.amount_usd, 2) as amount_usd,
    e.counterparty,
    e.detail
from all_evidence e
join alerted a using (account_key)

-- Grain: 1 row per score cutoff (every distinct positive risk_score).
-- Account level: an account is an alert when risk_score >= cutoff, and truly illicit when it
-- sent or received at least 1 labeled laundering payment.
-- Chosen cutoff: the lowest cutoff whose alerts stay within alert_budget_share (1%) of
-- active accounts. This rule uses alert volume only, never the label.
with accounts as (
    select risk_score, case when is_laundering_account then 1 else 0 end as is_pos
    from {{ ref('sc_account_risk') }}
),

totals as (
    select count(*) as n_accounts, sum(is_pos) as n_pos from accounts
),

by_score as (
    select risk_score, count(*) as n, sum(is_pos) as pos
    from accounts
    group by risk_score
),

cumulative as (
    select
        risk_score                                  as cutoff,
        sum(n)   over (order by risk_score desc)    as alerts,
        sum(pos) over (order by risk_score desc)    as tp
    from by_score
),

curve as (
    select
        c.cutoff,
        c.alerts,
        c.tp,
        c.alerts - c.tp                             as fp,
        t.n_pos - c.tp                              as fn,
        c.tp / c.alerts                             as precision,
        c.tp / t.n_pos                              as recall,
        c.alerts / t.n_accounts                     as alert_share,
        (c.tp / c.alerts) / (t.n_pos / t.n_accounts) as lift_over_base_rate,
        t.n_accounts,
        t.n_pos
    from cumulative c
    cross join totals t
    where c.cutoff > 0
)

select
    *,
    cutoff = (select min(cutoff) from curve where alert_share <= {{ var('alert_budget_share') }}) as is_chosen_cutoff
from curve
order by cutoff desc

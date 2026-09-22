-- Grain: 1 row per score cutoff (every distinct positive risk_score).
-- Account level: an account is an alert when risk_score >= cutoff, and truly illicit when it
-- sent or received at least 1 labeled laundering payment.
-- Chosen cutoff: pinned by the alert_cutoff variable. It is not re-derived per run, because
-- the holdout showed the budget rule below lands on 6 in one 5 day window and 4 in the next,
-- which would move the operating point between periods by accident.
-- is_budget_rule_cutoff still reports what that rule would pick: the lowest cutoff whose
-- alerts stay within alert_budget_share (1%) of active accounts, using alert volume only and
-- never the label. That rule is how the pinned value of 6 was originally chosen.
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
    cutoff = {{ var('alert_cutoff') }}                                                            as is_chosen_cutoff,
    cutoff = (select min(cutoff) from curve where alert_share <= {{ var('alert_budget_share') }}) as is_budget_rule_cutoff
from curve
order by cutoff desc

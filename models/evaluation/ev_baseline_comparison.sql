-- Grain: 1 row per ranker per alert budget.
-- Answers the first question a reviewer asks of any alerting model: does the risk score
-- beat simply ranking accounts by how busy they are?
--
-- Three rankers compete over the same 422,734 active accounts at an identical number of
-- alerts, so precision and recall are directly comparable:
--   model       risk_rank from sc_account_risk (weighted rule and typology flags)
--   txn_count   payments sent plus received, descending. The "busy account" critique in numeric form
--   usd_volume  USD sent plus received, descending
--   random_expected  the base rate, shown as the expected TP count at that budget
--
-- Budgets are the alert counts the model already produces in ev_cutoff_curve, plus the top 100,
-- so no budget is chosen to flatter the model.
-- No ranker reads the label. is_laundering_account is used only to score the outcome.
with accounts as (
    select
        account_key,
        risk_rank,
        case when is_laundering_account then 1 else 0 end as is_pos,
        n_txns_out + n_txns_in                            as n_txns_total,
        usd_out + usd_in                                  as usd_total
    from {{ ref('sc_account_risk') }}
),

totals as (
    select count(*) as n_accounts, sum(is_pos) as n_pos
    from accounts
),

ranked as (
    select
        is_pos,
        risk_rank                                                   as rank_model,
        row_number() over (order by n_txns_total desc, account_key) as rank_txn_count,
        row_number() over (order by usd_total desc, account_key)    as rank_usd_volume
    from accounts
),

long as (
    select 'model'      as ranker, rank_model      as rnk, is_pos from ranked
    union all
    select 'txn_count'  as ranker, rank_txn_count  as rnk, is_pos from ranked
    union all
    select 'usd_volume' as ranker, rank_usd_volume as rnk, is_pos from ranked
),

cumulative as (
    select
        ranker,
        rnk,
        sum(is_pos) over (
            partition by ranker
            order by rnk
            rows between unbounded preceding and current row
        ) as tp
    from long
),

budgets as (
    select distinct alerts as budget from {{ ref('ev_cutoff_curve') }}
    union
    select 100
),

measured as (
    select b.budget, c.ranker, cast(c.tp as double) as tp
    from budgets b
    join cumulative c on c.rnk = b.budget

    union all

    select b.budget, 'random_expected', b.budget * (t.n_pos * 1.0 / t.n_accounts)
    from budgets b
    cross join totals t
)

select
    m.budget                                                    as alert_budget,
    m.ranker,
    m.tp,
    m.budget - m.tp                                             as fp,
    t.n_pos - m.tp                                              as fn,
    m.tp / m.budget                                             as precision,
    m.tp / t.n_pos                                              as recall,
    (m.tp / m.budget) / (t.n_pos * 1.0 / t.n_accounts)          as lift_over_base_rate,
    t.n_accounts,
    t.n_pos
from measured m
cross join totals t
order by m.budget, m.ranker

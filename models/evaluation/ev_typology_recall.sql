-- Grain: 1 row per labeled typology, plus 1 row for illicit payments in no named pattern.
-- attempt_recall: share of attempts where at least 1 participating account scores at or
--   above the chosen cutoff (one alert is enough to open a case).
-- account_recall: share of participating accounts at or above the cutoff.
-- matching_detector_*: the same, using only the Phase 2 detector built for that typology
--   (STACK, BIPARTITE and RANDOM have no dedicated detector).
with cutoff as (
    select cutoff from {{ ref('ev_cutoff_curve') }} where is_chosen_cutoff
),

participants as (
    select attempt_id, typology, from_account_key as account_key from {{ ref('int_pattern_transactions') }}
    union
    select attempt_id, typology, to_account_key from {{ ref('int_pattern_transactions') }}
),

unclassified as (
    select -1 as attempt_id, 'NOT CLASSIFIED' as typology, account_key
    from (
        select from_account_key as account_key from {{ ref('int_edges') }} e
        where e.is_laundering = 1 and e.txn_id not in (select txn_id from {{ ref('int_pattern_transactions') }})
        union
        select to_account_key from {{ ref('int_edges') }} e
        where e.is_laundering = 1 and e.txn_id not in (select txn_id from {{ ref('int_pattern_transactions') }})
    )
),

all_participants as (
    select * from participants
    union all
    select * from unclassified
),

scored as (
    select
        p.attempt_id,
        p.typology,
        p.account_key,
        coalesce(r.risk_score, 0) >= (select cutoff from cutoff)      as is_alert,
        case p.typology
            when 'FAN-OUT'        then r.f_fan_out = 1
            when 'FAN-IN'         then r.f_fan_in = 1
            when 'GATHER-SCATTER' then r.f_gather_scatter = 1
            when 'SCATTER-GATHER' then r.f_scatter_gather = 1
            when 'CYCLE'          then r.f_cycle_2 = 1 or r.f_cycle_3 = 1
        end                                                             as is_matching_detector
    from all_participants p
    left join {{ ref('sc_account_risk') }} r using (account_key)
),

by_attempt as (
    select attempt_id, typology,
           bool_or(is_alert) as attempt_alerted,
           bool_or(coalesce(is_matching_detector, false)) as attempt_matched
    from scored
    group by attempt_id, typology
)

select
    s.typology,
    case when s.typology = 'NOT CLASSIFIED' then null else a.n_attempts end            as n_attempts,
    case when s.typology = 'NOT CLASSIFIED' then null else a.n_attempts_alerted end    as n_attempts_alerted,
    case when s.typology = 'NOT CLASSIFIED' then null else a.n_attempts_alerted / a.n_attempts end as attempt_recall,
    count(*)                                                        as n_accounts,
    sum(case when s.is_alert then 1 else 0 end)                     as n_accounts_alerted,
    sum(case when s.is_alert then 1 else 0 end) / count(*)          as account_recall,
    case when s.typology in ('STACK', 'BIPARTITE', 'RANDOM', 'NOT CLASSIFIED') then null
         else a.n_attempts_matched / a.n_attempts end               as matching_detector_attempt_recall,
    case when s.typology in ('STACK', 'BIPARTITE', 'RANDOM', 'NOT CLASSIFIED') then null
         else sum(case when s.is_matching_detector then 1 else 0 end) / count(*) end as matching_detector_account_recall
from (select distinct typology, account_key, is_alert, is_matching_detector from scored) s
join (
    select typology,
           count(*) as n_attempts,
           sum(case when attempt_alerted then 1 else 0 end) as n_attempts_alerted,
           sum(case when attempt_matched then 1 else 0 end) as n_attempts_matched
    from by_attempt
    group by typology
) a using (typology)
group by s.typology, a.n_attempts, a.n_attempts_alerted, a.n_attempts_matched
order by s.typology = 'NOT CLASSIFIED', s.typology

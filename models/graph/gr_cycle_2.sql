-- Typology: 2-cycle. A pays B and B pays A, with the two relationships active within
-- graph_window_hours (72) of each other.
-- Time test on pairs, not single payments: the later first payment must come no more
-- than 72 hours after the earlier last payment. This is an approximation that can pass
-- pairs whose individual payments are further apart; stated in the methodology.
-- Grain: 1 row per unordered account pair (account_a < account_b).
select
    ab.from_account_key                         as account_a,
    ab.to_account_key                           as account_b,
    least(ab.first_ts, ba.first_ts)             as cycle_start_ts,
    ab.n_txns + ba.n_txns                       as n_txns,
    ab.usd_paid + ba.usd_paid                   as usd_paid
from {{ ref('gr_pairs') }} ab
join {{ ref('gr_pairs') }} ba
    on  ba.from_account_key = ab.to_account_key
    and ba.to_account_key   = ab.from_account_key
where ab.from_account_key < ab.to_account_key
  and greatest(ab.first_ts, ba.first_ts)
      <= least(ab.last_ts, ba.last_ts) + interval '{{ var("graph_window_hours") }} hours'

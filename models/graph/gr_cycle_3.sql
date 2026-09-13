-- Typology: 3-cycle. A pays B, B pays C, C pays A, three different accounts, with all
-- three relationships active within graph_window_hours (72) of each other (same pair-level
-- time test as gr_cycle_2).
-- Each triangle is written once: account_a is the smallest key of the three, which
-- removes the 2 rotations of the same cycle.
-- Grain: 1 row per directed 3-cycle.
select
    ab.from_account_key                                         as account_a,
    ab.to_account_key                                           as account_b,
    bc.to_account_key                                           as account_c,
    least(ab.first_ts, bc.first_ts, ca.first_ts)                as cycle_start_ts,
    ab.usd_paid + bc.usd_paid + ca.usd_paid                     as usd_paid
from {{ ref('gr_pairs') }} ab
join {{ ref('gr_pairs') }} bc
    on bc.from_account_key = ab.to_account_key
join {{ ref('gr_pairs') }} ca
    on  ca.from_account_key = bc.to_account_key
    and ca.to_account_key   = ab.from_account_key
where bc.to_account_key <> ab.from_account_key
  and ab.from_account_key < ab.to_account_key
  and ab.from_account_key < bc.to_account_key
  and greatest(ab.first_ts, bc.first_ts, ca.first_ts)
      <= least(ab.last_ts, bc.last_ts, ca.last_ts) + interval '{{ var("graph_window_hours") }} hours'

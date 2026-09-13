-- Rule: an account sends 3 or more payments between structuring_24h_floor_usd (5000) and
-- the threshold (10000) whose total goes above the threshold inside any rolling 24 hours.
-- First run without the floor flagged 1,146,096 payments (25.5%), mostly many small
-- payments from high-volume accounts, which is not splitting behaviour. Floor added
-- before any label was checked. The transaction that completes the pattern
-- (and any later one still inside the window) is flagged.
-- Grain: 1 row per flagged transaction.
with sub_threshold as (
    select txn_id, from_account_key, txn_ts, amount_paid_usd
    from {{ ref('int_edges') }}
    where amount_paid_usd >= {{ var('structuring_24h_floor_usd') }}
      and amount_paid_usd <  {{ var('reporting_threshold_usd') }}
),

rolling as (
    select
        *,
        count(*)             over last_24h as n_txns_24h,
        sum(amount_paid_usd) over last_24h as usd_24h
    from sub_threshold
    window last_24h as (
        partition by from_account_key
        order by txn_ts
        range between interval '24 hours' preceding and current row
    )
)

select txn_id, from_account_key, txn_ts, n_txns_24h, usd_24h
from rolling
where n_txns_24h >= {{ var('structuring_min_txns_24h') }}
  and usd_24h    >  {{ var('reporting_threshold_usd') }}

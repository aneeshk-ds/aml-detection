-- README sanity check: no Phase 1 rule may flag 0 transactions or every transaction.
-- Returns 1 row per rule that breaks the bound, so the test fails when any row comes back.
with counts as (
    select 'structuring_band' as rule_name, sum(case when flag_structuring_band then 1 else 0 end) as flagged, count(*) as n from {{ ref('det_transaction_flags') }}
    union all
    select 'structuring_24h', sum(case when flag_structuring_24h then 1 else 0 end), count(*) from {{ ref('det_transaction_flags') }}
    union all
    select 'pass_through', sum(case when flag_pass_through then 1 else 0 end), count(*) from {{ ref('det_transaction_flags') }}
    union all
    select 'high_velocity', sum(case when flag_high_velocity then 1 else 0 end), count(*) from {{ ref('det_transaction_flags') }}
    union all
    select 'round_amount', sum(case when flag_round_amount then 1 else 0 end), count(*) from {{ ref('det_transaction_flags') }}
    union all
    select 'cross_currency', sum(case when flag_cross_currency then 1 else 0 end), count(*) from {{ ref('det_transaction_flags') }}
)
select rule_name, flagged, n
from counts
where flagged = 0 or flagged = n

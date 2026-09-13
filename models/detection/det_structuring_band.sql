-- Rule: USD value sits just under the reporting threshold (9000 to 9999.99 by default).
-- Grain: 1 row per flagged transaction.
select
    txn_id,
    from_account_key,
    txn_ts,
    amount_paid_usd
from {{ ref('int_edges') }}
where amount_paid_usd >= {{ var('structuring_band_low_usd') }}
  and amount_paid_usd <  {{ var('reporting_threshold_usd') }}

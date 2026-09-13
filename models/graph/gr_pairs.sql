-- Grain: 1 row per directed account pair (sender, receiver) that transacted at least once.
-- Collapses 4,487,133 payments into their relationships so graph joins run on pairs.
select
    from_account_key,
    to_account_key,
    count(*)                as n_txns,
    min(txn_ts)             as first_ts,
    max(txn_ts)             as last_ts,
    sum(amount_paid_usd)    as usd_paid
from {{ ref('int_edges') }}
group by from_account_key, to_account_key

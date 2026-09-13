-- Rule: the receiving currency differs from the payment currency.
-- Phase 0 found 0 illicit rows among cross-currency payments, so this rule is kept as a
-- documented negative result rather than silently dropped.
-- Grain: 1 row per flagged transaction.
select
    txn_id,
    from_account_key,
    txn_ts,
    payment_currency,
    amount_paid_usd
from {{ ref('int_edges') }}
where is_cross_currency

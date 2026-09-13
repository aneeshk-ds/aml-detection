-- Grain: 1 row per transaction listed in a labeled laundering attempt, linked to txn_id.
-- Phase 0 verified all 3,209 pattern lines match exactly 1 transaction on every field.
-- Evaluation only.
{{ config(materialized = 'table') }}

select
    p.attempt_id,
    p.typology,
    p.typology_detail,
    t.txn_id,
    t.from_account_key,
    t.to_account_key
from {{ ref('stg_patterns') }} p
join {{ ref('stg_transactions') }} t
    on  t.txn_ts             = p.txn_ts
    and t.from_account_key   = p.from_account_key
    and t.to_account_key     = p.to_account_key
    and t.amount_paid        = p.amount_paid
    and t.payment_currency   = p.payment_currency
    and t.amount_received    = p.amount_received
    and t.receiving_currency = p.receiving_currency
    and t.payment_format     = p.payment_format

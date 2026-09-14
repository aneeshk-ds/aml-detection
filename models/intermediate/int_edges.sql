-- Grain: 1 row per transaction between two different accounts (self-transfers removed
-- when exclude_self_transfers is true). Every Phase 1 and Phase 2 model reads from here.
-- is_laundering is carried only for evaluation; no detection model filters on it.
-- When use_sample is true this becomes a table so the seeded sample is fixed once.
{{ config(materialized = 'table' if var('use_sample') else 'view') }}

select
    txn_id,
    txn_ts,
    from_account_key,
    to_account_key,
    amount_paid,
    payment_currency,
    amount_paid_usd,
    amount_received_usd,
    payment_format,
    is_cross_currency,
    is_laundering
from {{ ref('int_transactions_usd') }}
where 1 = 1
{% if var('exclude_self_transfers') %}
  and not is_self_transfer
{% endif %}
{% if var('window_start') != 'all' %}
  and txn_ts >= timestamp '{{ var("window_start") }}'
  and txn_ts <  timestamp '{{ var("window_end") }}'
{% endif %}
{% if var('use_sample') %}
using sample reservoir({{ var('sample_rows') }} rows) repeatable ({{ var('sample_seed') }})
{% endif %}

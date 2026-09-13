-- Grain: 1 row per transaction in int_edges, with one boolean per Phase 1 rule.
-- Joins every rule model back to the full transaction list so unflagged rows read false.
select
    e.txn_id,
    e.txn_ts,
    e.from_account_key,
    e.to_account_key,
    e.amount_paid_usd,
    e.payment_format,
    e.is_laundering,
    sb.txn_id is not null   as flag_structuring_band,
    s24.txn_id is not null  as flag_structuring_24h,
    pt.txn_id is not null   as flag_pass_through,
    hv.txn_id is not null   as flag_high_velocity,
    ra.txn_id is not null   as flag_round_amount,
    cc.txn_id is not null   as flag_cross_currency
from {{ ref('int_edges') }} e
left join {{ ref('det_structuring_band') }} sb  on sb.txn_id  = e.txn_id
left join {{ ref('det_structuring_24h') }}  s24 on s24.txn_id = e.txn_id
left join {{ ref('det_pass_through') }}     pt  on pt.txn_id  = e.txn_id
left join {{ ref('det_high_velocity') }}    hv  on hv.txn_id  = e.txn_id
left join {{ ref('det_round_amount') }}     ra  on ra.txn_id  = e.txn_id
left join {{ ref('det_cross_currency') }}   cc  on cc.txn_id  = e.txn_id

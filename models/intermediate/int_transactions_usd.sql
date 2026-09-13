-- Grain: 1 row per transaction (same as stg_transactions), plus both amounts in USD.
-- Every later phase reads from this model, so thresholds are compared in one currency.
select
    t.*,
    t.amount_paid     * fx_paid.usd_per_unit       as amount_paid_usd,
    t.amount_received * fx_recv.usd_per_unit       as amount_received_usd
from {{ ref('stg_transactions') }} t
left join {{ ref('stg_fx_rates') }} fx_paid
    on fx_paid.currency = t.payment_currency
left join {{ ref('stg_fx_rates') }} fx_recv
    on fx_recv.currency = t.receiving_currency

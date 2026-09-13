-- Grain: 1 row per currency. usd_per_unit is the US Dollar value of 1 unit.
-- No outside exchange rates: the rate is the median implied by rows where one side
-- of the transaction is US Dollar and the other side is the currency.
-- p05 and p95 show how stable the implied rate is across those rows.
{{ config(materialized = 'table') }}

with pairs as (
    select
        payment_currency                    as currency,
        amount_received / amount_paid       as usd_per_unit
    from {{ ref('stg_transactions') }}
    where receiving_currency = 'US Dollar'
      and payment_currency <> 'US Dollar'

    union all

    select
        receiving_currency                  as currency,
        amount_paid / amount_received       as usd_per_unit
    from {{ ref('stg_transactions') }}
    where payment_currency = 'US Dollar'
      and receiving_currency <> 'US Dollar'
),

rates as (
    select
        currency,
        median(usd_per_unit)                    as usd_per_unit,
        quantile_cont(usd_per_unit, 0.05)       as usd_per_unit_p05,
        quantile_cont(usd_per_unit, 0.95)       as usd_per_unit_p95,
        count(*)                                as n_pair_rows
    from pairs
    group by currency
)

select 'US Dollar' as currency, 1.0 as usd_per_unit, 1.0 as usd_per_unit_p05, 1.0 as usd_per_unit_p95, null::bigint as n_pair_rows
union all
select currency, usd_per_unit, usd_per_unit_p05, usd_per_unit_p95, n_pair_rows
from rates

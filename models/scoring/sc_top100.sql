-- Grain: 1 row per account, the 100 highest-risk accounts. Written to outputs/ranked_accounts.csv.
-- The laundering label is left out on purpose: this is the alert list an analyst would see.
{{ config(materialized = 'external', location = var('output_dir', 'outputs') ~ '/ranked_accounts.csv', format = 'csv') }}

select
    r.risk_rank,
    r.account_key,
    a.bank_name,
    a.entity_name,
    r.risk_score,
    r.n_flag_types,
    r.f_pass_through, r.f_cycle_3, r.f_scatter_gather, r.f_gather_scatter,
    r.f_structuring_24h, r.f_fan_out, r.f_fan_in,
    r.f_cycle_2, r.f_structuring_band, r.f_high_velocity, r.f_round_amount, r.f_cross_currency,
    r.n_txns_out,
    r.n_txns_in,
    round(r.usd_out, 2) as usd_out,
    round(r.usd_in, 2)  as usd_in
from {{ ref('sc_account_risk') }} r
join {{ ref('stg_accounts') }} a using (account_key)
where r.risk_rank <= 100
order by r.risk_rank

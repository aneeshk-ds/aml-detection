-- Rule: an account's outbound count inside a rolling 24 hours is above the 99th
-- percentile of every sending account's peak 24 hour count.
-- Strictly above, so ties at the percentile value do not push the share past 1%.
-- Grain: 1 row per flagged transaction.
with rolling as (
    select
        txn_id,
        from_account_key,
        txn_ts,
        count(*) over (
            partition by from_account_key
            order by txn_ts
            range between interval '24 hours' preceding and current row
        ) as n_out_24h
    from {{ ref('int_edges') }}
),

account_peak as (
    select from_account_key, max(n_out_24h) as peak_out_24h
    from rolling
    group by from_account_key
),

threshold as (
    select quantile_disc(peak_out_24h, {{ var('velocity_percentile') }}) as velocity_threshold
    from account_peak
)

select r.txn_id, r.from_account_key, r.txn_ts, r.n_out_24h, t.velocity_threshold
from rolling r
cross join threshold t
where r.n_out_24h > t.velocity_threshold

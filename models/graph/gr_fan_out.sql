-- Typology: fan-out. An account starts paying fan_k (5) or more new receivers inside a
-- rolling graph_window_hours (72). "New" = first payment to that receiver, taken from
-- gr_pairs.first_ts, so each receiver counts once.
-- Grain: 1 row per detection event (the pair start that reaches k).
with rolling as (
    select
        from_account_key                as account_key,
        first_ts                        as detect_ts,
        count(*) over (
            partition by from_account_key
            order by first_ts
            range between interval '{{ var("graph_window_hours") }} hours' preceding and current row
        )                               as new_counterparties_window
    from {{ ref('gr_pairs') }}
)

select account_key, detect_ts, new_counterparties_window
from rolling
where new_counterparties_window >= {{ var('fan_k') }}

-- Typology: fan-in. Mirror of gr_fan_out: an account starts receiving from fan_k (5) or
-- more new senders inside a rolling graph_window_hours (72).
-- Grain: 1 row per detection event.
with rolling as (
    select
        to_account_key                  as account_key,
        first_ts                        as detect_ts,
        count(*) over (
            partition by to_account_key
            order by first_ts
            range between interval '{{ var("graph_window_hours") }} hours' preceding and current row
        )                               as new_counterparties_window
    from {{ ref('gr_pairs') }}
)

select account_key, detect_ts, new_counterparties_window
from rolling
where new_counterparties_window >= {{ var('fan_k') }}

-- Typology: gather-scatter. The same account has a fan-in event and then a fan-out event
-- that starts no later than graph_window_hours (72) after it: many in, then many out.
-- Grain: 1 row per account.
select
    i.account_key,
    min(i.detect_ts)    as first_gather_ts,
    count(*)            as n_gather_events_followed_by_scatter
from {{ ref('gr_fan_in') }} i
where exists (
    select 1
    from {{ ref('gr_fan_out') }} o
    where o.account_key = i.account_key
      and o.detect_ts >= i.detect_ts
      and o.detect_ts <= i.detect_ts + interval '{{ var("graph_window_hours") }} hours'
)
group by i.account_key

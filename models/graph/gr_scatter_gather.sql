-- Typology: scatter-gather. A source pays scatter_gather_k (3) or more different
-- intermediaries, and each of those intermediaries pays the same sink, with the second
-- hop active no later than graph_window_hours (72) after the first hop ends and not
-- entirely before it starts.
-- Grain: 1 row per (source, sink, intermediary) in a qualifying source-sink route.
with two_hop as (
    select
        s.from_account_key      as source_key,
        s.to_account_key        as intermediary_key,
        g.to_account_key        as sink_key,
        least(s.first_ts, g.first_ts) as start_ts
    from {{ ref('gr_pairs') }} s
    join {{ ref('gr_pairs') }} g
        on g.from_account_key = s.to_account_key
    where g.to_account_key <> s.from_account_key
      and g.last_ts  >= s.first_ts
      and g.first_ts <= s.last_ts + interval '{{ var("graph_window_hours") }} hours'
),

routes as (
    select source_key, sink_key, count(distinct intermediary_key) as n_intermediaries
    from two_hop
    group by source_key, sink_key
    having count(distinct intermediary_key) >= {{ var('scatter_gather_k') }}
)

select t.source_key, t.sink_key, t.intermediary_key, r.n_intermediaries, t.start_ts
from two_hop t
join routes r
    on  r.source_key = t.source_key
    and r.sink_key   = t.sink_key

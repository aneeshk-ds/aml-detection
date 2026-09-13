-- Fails if any Phase 2 detector finds nothing.
with counts as (
    select 'fan_out' as detector, count(*) as n from {{ ref('gr_fan_out') }}
    union all select 'fan_in', count(*) from {{ ref('gr_fan_in') }}
    union all select 'gather_scatter', count(*) from {{ ref('gr_gather_scatter') }}
    union all select 'cycle_2', count(*) from {{ ref('gr_cycle_2') }}
    union all select 'cycle_3', count(*) from {{ ref('gr_cycle_3') }}
    union all select 'scatter_gather', count(*) from {{ ref('gr_scatter_gather') }}
)
select detector, n from counts where n = 0

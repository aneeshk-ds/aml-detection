-- Rule: inside a rolling 48 hours an account takes in at least pass_through_min_inflow_usd
-- and sends out between 90% and 110% of it (keeps less than 10%). The outbound payment
-- that brings the account into that state is flagged.
-- Inbound and outbound payments are stacked into one event list per account so a single
-- window can total both sides.
-- Grain: 1 row per flagged outbound transaction.
with events as (
    select
        to_account_key          as account_key,
        txn_ts,
        amount_received_usd     as usd_in,
        0.0                     as usd_out,
        null::bigint            as txn_id
    from {{ ref('int_edges') }}

    union all

    select
        from_account_key        as account_key,
        txn_ts,
        0.0                     as usd_in,
        amount_paid_usd         as usd_out,
        txn_id
    from {{ ref('int_edges') }}
),

rolling as (
    select
        *,
        sum(usd_in)  over window_48h as in_usd_48h,
        sum(usd_out) over window_48h as out_usd_48h
    from events
    window window_48h as (
        partition by account_key
        order by txn_ts
        range between interval '{{ var("pass_through_window_hours") }} hours' preceding and current row
    )
)

select
    txn_id,
    account_key                     as from_account_key,
    txn_ts,
    in_usd_48h,
    out_usd_48h,
    1 - out_usd_48h / in_usd_48h    as retention_48h
from rolling
where txn_id is not null
  and in_usd_48h  >= {{ var('pass_through_min_inflow_usd') }}
  and out_usd_48h >= in_usd_48h * (1 - {{ var('pass_through_max_retention') }})
  and out_usd_48h <= in_usd_48h * (1 + {{ var('pass_through_max_retention') }})

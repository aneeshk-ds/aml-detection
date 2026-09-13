-- Grain: 1 row per line of HI-Small_Trans.csv.
-- The source has no transaction id, so txn_id is the 1-based file row order.
-- Banks are zero-padded text in this file ("010") but plain numbers in the accounts
-- file ("10"), so account keys use the integer bank id. Checked before building:
-- the integer key gives the same distinct sender (496,999) and receiver (420,640)
-- account counts as the text key, so no accounts are merged.
{{ config(
    materialized = 'table',
    pre_hook = "set preserve_insertion_order = true"
) }}

with src as (
    select * from {{ source('raw', 'hi_small_trans') }}
),

numbered as (
    select
        row_number() over () as txn_id,
        *
    from src
)

select
    txn_id,
    strptime(ts, '%Y/%m/%d %H:%M')                                    as txn_ts,
    cast(from_bank as bigint)                                         as from_bank_id,
    from_acct                                                         as from_account,
    cast(cast(from_bank as bigint) as varchar) || '_' || from_acct    as from_account_key,
    cast(to_bank as bigint)                                           as to_bank_id,
    to_acct                                                           as to_account,
    cast(cast(to_bank as bigint) as varchar) || '_' || to_acct        as to_account_key,
    cast(amt_recv as double)                                          as amount_received,
    recv_cur                                                          as receiving_currency,
    cast(amt_paid as double)                                          as amount_paid,
    pay_cur                                                           as payment_currency,
    pay_fmt                                                           as payment_format,
    cast(is_laundering as integer)                                    as is_laundering,
    (cast(from_bank as bigint) = cast(to_bank as bigint)
        and from_acct = to_acct)                                      as is_self_transfer,
    (recv_cur <> pay_cur)                                             as is_cross_currency
from numbered

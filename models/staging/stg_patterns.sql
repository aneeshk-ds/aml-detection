-- Grain: 1 row per transaction line inside HI-Small_Patterns.txt.
-- The file is not a CSV. It is a sequence of blocks:
--   BEGIN LAUNDERING ATTEMPT - <TYPOLOGY>: <detail>
--   <transaction lines in the same layout as HI-Small_Trans.csv>
--   END LAUNDERING ATTEMPT - <TYPOLOGY>
-- A running count of BEGIN lines gives every line the id of the attempt it belongs to.
{{ config(materialized = 'table') }}

with file_text as (
    select string_split(replace(content, chr(13), ''), chr(10)) as parts
    from {{ source('raw', 'hi_small_patterns') }}
),

lines as (
    select
        generate_subscripts(parts, 1)   as line_no,
        unnest(parts)                   as line
    from file_text
),

tagged as (
    select
        line_no,
        trim(line) as line,
        sum(case when line like 'BEGIN LAUNDERING ATTEMPT%' then 1 else 0 end)
            over (order by line_no)     as attempt_id
    from lines
),

headers as (
    select
        attempt_id,
        regexp_extract(line, 'BEGIN LAUNDERING ATTEMPT - ([A-Z-]+)', 1)   as typology,
        trim(regexp_extract(line, ':(.*)$', 1))                            as typology_detail
    from tagged
    where line like 'BEGIN LAUNDERING ATTEMPT%'
),

txn_lines as (
    select attempt_id, line_no, string_split(line, ',') as f
    from tagged
    where line <> ''
      and line not like 'BEGIN LAUNDERING ATTEMPT%'
      and line not like 'END LAUNDERING ATTEMPT%'
)

select
    t.attempt_id,
    h.typology,
    h.typology_detail,
    t.line_no,
    strptime(f[1], '%Y/%m/%d %H:%M')                                  as txn_ts,
    cast(f[2] as bigint)                                              as from_bank_id,
    f[3]                                                              as from_account,
    cast(cast(f[2] as bigint) as varchar) || '_' || f[3]              as from_account_key,
    cast(f[4] as bigint)                                              as to_bank_id,
    f[5]                                                              as to_account,
    cast(cast(f[4] as bigint) as varchar) || '_' || f[5]              as to_account_key,
    cast(f[6] as double)                                              as amount_received,
    f[7]                                                              as receiving_currency,
    cast(f[8] as double)                                              as amount_paid,
    f[9]                                                              as payment_currency,
    f[10]                                                             as payment_format,
    cast(f[11] as integer)                                            as is_laundering
from txn_lines t
join headers h using (attempt_id)

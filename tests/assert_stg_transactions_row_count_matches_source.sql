-- Fails (returns a row) if staging dropped or duplicated any line of the source CSV.
with source_rows as (
    select count(*) as n from {{ source('raw', 'hi_small_trans') }}
),
staged_rows as (
    select count(*) as n from {{ ref('stg_transactions') }}
)
select source_rows.n as source_rows, staged_rows.n as staged_rows
from source_rows, staged_rows
where source_rows.n <> staged_rows.n

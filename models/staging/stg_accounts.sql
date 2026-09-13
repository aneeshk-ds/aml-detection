-- Grain: 1 row per account in HI-Small_accounts.csv.
-- account_key matches stg_transactions: integer bank id, underscore, account number.
select
    cast(cast(bank_id as bigint) as varchar) || '_' || account_number   as account_key,
    cast(bank_id as bigint)                                             as bank_id,
    bank_name,
    account_number,
    entity_id,
    entity_name
from {{ source('raw', 'hi_small_accounts') }}

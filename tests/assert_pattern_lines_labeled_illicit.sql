-- Fails if any transaction listed inside a laundering attempt is not labeled 1.
select attempt_id, line_no, is_laundering
from {{ ref('stg_patterns') }}
where is_laundering <> 1

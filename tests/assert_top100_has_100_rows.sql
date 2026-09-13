-- Fails unless the ranked output holds exactly 100 accounts.
select count(*) as n_rows
from {{ ref('sc_top100') }}
having count(*) <> 100

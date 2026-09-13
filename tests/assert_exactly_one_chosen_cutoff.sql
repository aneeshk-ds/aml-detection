-- Fails unless the cutoff rule selects exactly 1 score cutoff.
select count(*) as n_chosen
from {{ ref('ev_cutoff_curve') }}
where is_chosen_cutoff
having count(*) <> 1

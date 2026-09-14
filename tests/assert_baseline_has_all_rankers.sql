-- Fails if any alert budget is missing one of the 4 rankers. A budget with a missing
-- ranker would silently turn a like-for-like comparison into an incomplete one.
select alert_budget, count(distinct ranker) as n_rankers
from {{ ref('ev_baseline_comparison') }}
group by alert_budget
having count(distinct ranker) <> 4

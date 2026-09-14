-- Fails if the baseline model stops reproducing the 2 published figures in metrics.md:
-- 270 true positives at the 2,147 alert operating point, and 41 in the top 100.
-- This is the anchor proving ev_baseline_comparison scores the same accounts the
-- headline results score, so the baseline margin cannot drift away from the metrics.
select alert_budget, tp
from {{ ref('ev_baseline_comparison') }}
where ranker = 'model'
  and (
        (alert_budget = 2147 and tp <> 270)
     or (alert_budget = 100  and tp <> 41)
  )

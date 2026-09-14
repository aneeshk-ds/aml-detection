# AML Detection Metrics

Run date: 2026-09-11. Data: IBM Transactions for AML, HI-Small (synthetic, Altman, Kaggle). Every number below comes from the `ev_` models in DuckDB.

## Headline at the chosen cutoff

- **Illicit ratio:** 0.102% of all 5,078,345 payments; 0.115% of the 4,487,133 payments between different accounts (5,166 illicit)
- **Account base rate:** 6,357 of 422,734 active accounts touched a laundering payment (1.50%)
- **Chosen cutoff:** risk_score >= 6, the lowest cutoff that keeps alerts within 1% of active accounts (cutoff 5 would alert 1.37%)
- **Alerts:** 2,147 (0.51% of active accounts)
- **True positives / false positives / false negatives:** 270 / 1,877 / 6,087
- **Precision:** 12.58%, which is 8.4 times the base rate and 2.09 times the best activity baseline
- **Recall:** 4.25%
- **Precision in the top 100:** 41% (41 of 100); top 10: 8 of 10

## Precision and recall across cutoffs

| Cutoff | Alerts | % of accounts | TP | FP | FN | Precision | Recall | Lift |
|---|---|---|---|---|---|---|---|---|
| 15 | 3 | 0.001% | 3 | 0 | 6,354 | 100.0% | 0.05% | 66.5 |
| 14 | 4 | 0.001% | 4 | 0 | 6,353 | 100.0% | 0.06% | 66.5 |
| 13 | 5 | 0.001% | 5 | 0 | 6,352 | 100.0% | 0.08% | 66.5 |
| 12 | 9 | 0.002% | 7 | 2 | 6,350 | 77.8% | 0.11% | 51.7 |
| 11 | 32 | 0.008% | 24 | 8 | 6,333 | 75.0% | 0.38% | 49.9 |
| 10 | 62 | 0.015% | 39 | 23 | 6,318 | 62.9% | 0.61% | 41.8 |
| 9 | 155 | 0.037% | 50 | 105 | 6,307 | 32.3% | 0.79% | 21.5 |
| 8 | 459 | 0.109% | 88 | 371 | 6,269 | 19.2% | 1.38% | 12.7 |
| 7 | 896 | 0.212% | 142 | 754 | 6,215 | 15.8% | 2.23% | 10.5 |
| 6 (chosen) | 2,147 | 0.508% | 270 | 1,877 | 6,087 | 12.6% | 4.25% | 8.4 |
| 5 | 5,809 | 1.374% | 403 | 5,406 | 5,954 | 6.9% | 6.34% | 4.6 |
| 4 | 8,118 | 1.920% | 490 | 7,628 | 5,867 | 6.0% | 7.71% | 4.0 |
| 3 | 25,670 | 6.072% | 1,262 | 24,408 | 5,095 | 4.9% | 19.85% | 3.3 |
| 2 | 43,983 | 10.404% | 1,825 | 42,158 | 4,532 | 4.1% | 28.71% | 2.8 |
| 1 | 51,310 | 12.138% | 2,162 | 49,148 | 4,195 | 4.2% | 34.01% | 2.8 |

Moving from cutoff 11 to cutoff 1 multiplies alerts by 1,603 (32 to 51,310) while recall rises from 0.38% to 34.01% and precision falls from 75.0% to 4.2%.

## Per-flag performance

Account level (base rate 1.50%):

| Flag | Accounts flagged | TP | Precision | Recall | Lift |
|---|---|---|---|---|---|
| scatter_gather | 499 | 342 | 68.5% | 5.38% | 45.6 |
| gather_scatter | 109 | 44 | 40.4% | 0.69% | 26.8 |
| cycle_3 | 213 | 41 | 19.2% | 0.64% | 12.8 |
| cycle_2 | 3,934 | 370 | 9.4% | 5.82% | 6.3 |
| fan_in | 7,975 | 586 | 7.3% | 9.22% | 4.9 |
| high_velocity | 2,963 | 157 | 5.3% | 2.47% | 3.5 |
| round_amount | 25 | 1 | 4.0% | 0.02% | 2.7 |
| pass_through | 17,606 | 672 | 3.8% | 10.57% | 2.5 |
| structuring_band | 9,269 | 343 | 3.7% | 5.40% | 2.5 |
| structuring_24h | 7,538 | 235 | 3.1% | 3.70% | 2.1 |
| fan_out | 17,942 | 481 | 2.7% | 7.57% | 1.8 |
| cross_currency | 280 | 2 | 0.7% | 0.03% | 0.5 |

Transaction level, Phase 1 rules (base rate 0.115%):

| Rule | Payments flagged | TP | Precision | Recall | Lift |
|---|---|---|---|---|---|
| pass_through | 49,634 | 304 | 0.612% | 5.88% | 5.3 |
| structuring_band | 40,700 | 149 | 0.366% | 2.88% | 3.2 |
| structuring_24h | 80,420 | 106 | 0.132% | 2.05% | 1.1 |
| high_velocity | 509,124 | 654 | 0.128% | 12.66% | 1.1 |
| round_amount | 64 | 0 | 0.000% | 0.00% | 0.0 |
| cross_currency | 2,191 | 0 | 0.000% | 0.00% | 0.0 |

## Per-typology recall at cutoff 6

An attempt counts as caught when at least 1 of its accounts is alerted, because 1 alert opens the case.

| Typology | Attempts | Attempts caught | Attempt recall | Accounts | Accounts alerted | Account recall |
|---|---|---|---|---|---|---|
| SCATTER-GATHER | 44 | 39 | 88.6% | 369 | 111 | 30.1% |
| GATHER-SCATTER | 51 | 43 | 84.3% | 685 | 58 | 8.5% |
| BIPARTITE | 49 | 28 | 57.1% | 491 | 28 | 5.7% |
| STACK | 43 | 23 | 53.5% | 663 | 37 | 5.6% |
| CYCLE | 54 | 23 | 42.6% | 271 | 35 | 12.9% |
| FAN-IN | 40 | 17 | 42.5% | 338 | 29 | 8.6% |
| FAN-OUT | 48 | 20 | 41.7% | 359 | 30 | 8.4% |
| RANDOM | 41 | 16 | 39.0% | 211 | 23 | 10.9% |
| NOT CLASSIFIED (1,968 illicit payments in no pattern) | n/a | n/a | n/a | 3,227 | 37 | 1.1% |

Across the 8 named typologies, 209 of 370 attempts (56.5%) have at least 1 alerted account.

## Against the obvious baseline

Ranking the same 422,734 accounts by activity instead of by risk score, at identical alert budgets:

| Alert budget | Model TP | By payment count | By USD volume | Random expected | Model vs best baseline |
|---|---|---|---|---|---|
| 100 | 41 | 22 | 14 | 1.5 | 1.86x |
| 896 | 142 | 73 | 39 | 13.5 | 1.95x |
| 2,147 (chosen) | 270 | 129 | 68 | 32.3 | 2.09x |
| 8,118 | 490 | 301 | 227 | 122.1 | 1.63x |
| 51,310 | 2,162 | 1,102 | 1,156 | 771.6 | 1.87x |

Payment-count ranking alone reaches 6.01% precision at the chosen budget, 4.0 times the base rate, with no model at all. The 8.4 times headline is measured against random selection; against the baseline a reviewer would propose, the score is worth 2.09 times. The margin holds between 1.6x and 2.2x at every budget from 32 to 51,310. Full curve, method and limitations: [baseline_comparison.md](baseline_comparison.md).

## Where this approach is weak

At cutoff 6 the score raises 2,147 alerts and 270 are illicit accounts: 12.6% precision, 8.4 times the base rate, but 4.2% recall, so 6,087 of 6,357 illicit accounts are never alerted. The score correlates with activity: alerted accounts have a median of 109 payments, illicit accounts 19 and unflagged accounts 5, and 64 of the top 100 sit in the top 1% of accounts by payment count, so busy accounts crowd out quiet launderers. It is not merely a proxy for size, since it beats payment-count ranking 2.09 to 1 at the same alert budget, but activity alone still reaches 4.0 times lift, so part of the edge is size rather than behaviour. The account label is broad: an account that received 1 laundering payment counts as illicit, and a single inbound payment rarely trips any rule. Coverage has gaps: the 1,968 illicit payments outside named patterns touch 3,227 accounts and 37 (1.1%) are alerted; SQL closes cycles of exactly 3 accounts only; the cross-currency and round-amount rules flag 0 illicit payments. Cycle and scatter-gather timing is tested on account pairs, not single payments. Thresholds and weights are hand-set and have not been checked on a time-based holdout, Bitcoin USD values are approximate (implied rate 10,000 to 20,000), and the data is synthetic, so none of these rates transfer directly to a real bank.

## What a bank would tune next

1. Peer-group thresholds by entity type and activity band. The baseline test shows the score is not merely tracking volume, so this is a recall play against quiet launderers rather than a correction.
2. Weight 0 for cross_currency and round_amount, confirmed on held-out days rather than the same labels.
3. A time split: set thresholds on 2022-09-01 to 09-05 and report on 09-06 to 09-10.
4. Longer cycles and dense subgraphs with graph tooling (Phase 5).
5. Analyst dispositions on the 2,147 alerts to learn weights from reviewed cases.
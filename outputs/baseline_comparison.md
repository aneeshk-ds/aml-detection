# Does the risk score beat ranking accounts by activity?

Run date: 2026-09-14. Every number comes from the `ev_baseline_comparison` model, built on
`sc_account_risk` over the same 422,734 active accounts used everywhere else in this project.
6,357 of them touched a laundering payment, a base rate of 1.50%.

## The question this answers

The documented weakness of this pipeline is that the score follows activity. Alerted accounts
have a median of 109 payments against 19 for illicit accounts, and 64 of the top 100 sit in the
busiest 1% of accounts. If activity is all the score captures, an analyst could skip the whole
pipeline and sort accounts by payment count instead.

So the score is made to compete against that shortcut at an identical alert volume.

## Method

Four rankers order the same 422,734 accounts. None of them reads the laundering label. The
label is used only to score the outcome afterwards.

| Ranker | Ordering |
|---|---|
| `model` | `risk_rank` from `sc_account_risk`, the weighted rule and typology score |
| `txn_count` | payments sent plus received, descending |
| `usd_volume` | USD sent plus received, descending |
| `random_expected` | no ordering. The expected true positives at that budget from the 1.50% base rate |

Each ranker is cut at the same 16 alert budgets. 15 of them are the alert counts the model
already produces in `ev_cutoff_curve`, so no budget was picked to flatter the model, plus the
top 100 to match the published top-100 figure. Ties break on `account_key`, which is
deterministic and carries no signal.

Correctness anchor: at budget 2,147 the model reproduces 270 true positives and 12.58%
precision, and at budget 100 it reproduces 41 true positives. Both match `metrics.md` exactly,
which confirms this model measures the same thing the published results measure.

## Results

True positives at matched alert volume:

| Alert budget | Model | By payment count | By USD volume | Random | Model precision | Count precision | Volume precision | Model vs best baseline |
|---|---|---|---|---|---|---|---|---|
| 3 | 3 | 3 | 2 | 0.0 | 100.00% | 100.00% | 66.67% | 1.00x |
| 4 | 4 | 4 | 2 | 0.1 | 100.00% | 100.00% | 50.00% | 1.00x |
| 5 | 5 | 5 | 2 | 0.1 | 100.00% | 100.00% | 40.00% | 1.00x |
| 9 | 7 | 9 | 3 | 0.1 | 77.78% | 100.00% | 33.33% | 0.78x |
| 32 | 24 | 15 | 6 | 0.5 | 75.00% | 46.88% | 18.75% | 1.60x |
| 62 | 39 | 18 | 9 | 0.9 | 62.90% | 29.03% | 14.52% | 2.17x |
| 100 | 41 | 22 | 14 | 1.5 | 41.00% | 22.00% | 14.00% | 1.86x |
| 155 | 50 | 27 | 16 | 2.3 | 32.26% | 17.42% | 10.32% | 1.85x |
| 459 | 88 | 51 | 30 | 6.9 | 19.17% | 11.11% | 6.54% | 1.73x |
| 896 | 142 | 73 | 39 | 13.5 | 15.85% | 8.15% | 4.35% | 1.95x |
| **2,147 (operating point)** | **270** | **129** | **68** | **32.3** | **12.58%** | **6.01%** | **3.17%** | **2.09x** |
| 5,809 | 403 | 244 | 153 | 87.4 | 6.94% | 4.20% | 2.63% | 1.65x |
| 8,118 | 490 | 301 | 227 | 122.1 | 6.04% | 3.71% | 2.80% | 1.63x |
| 25,670 | 1,262 | 637 | 625 | 386.0 | 4.92% | 2.48% | 2.43% | 1.98x |
| 43,983 | 1,825 | 977 | 1,000 | 661.4 | 4.15% | 2.22% | 2.27% | 1.82x |
| 51,310 | 2,162 | 1,102 | 1,156 | 771.6 | 4.21% | 2.15% | 2.25% | 1.87x |

Recall at the operating point: 4.25% for the model, 2.03% for payment count, 1.07% for USD volume.

## What the numbers say

The score is not a proxy for account size. At the 2,147 alert operating point it finds 270
illicit accounts against 129 for payment-count ranking, so it doubles the best naive baseline
at the same cost to the alert queue. The margin holds between 1.6x and 2.2x across every budget
from 32 to 51,310, which means the result is not an artifact of where the cutoff sits.

The more useful correction is to the headline figure. This project reports 8.4 times lift over
the 1.50% base rate at cutoff 6. That comparison is against random selection, and random is not
the alternative any bank would actually use. Ranking by payment count alone reaches 6.01%
precision at the same budget, which is 4.0 times the base rate. Measured against the baseline a
reviewer would propose, the score is worth 2.09 times, not 8.4 times. Both numbers are true and
the second one is the honest one.

Activity is genuinely predictive, which is why the original critique was worth taking seriously.
Payment-count ranking beats random by 4.0 times with no model at all. The finding is that the
rules and typologies add roughly as much again on top of it.

Payment count is the stronger of the two shortcuts. USD volume trails it at every budget above
5 and is beaten almost 2 to 1 at the operating point, so moving large sums matters less than
moving many times.

## Where it loses

At budget 9 the model finds 7 illicit accounts and payment-count ranking finds 9. That is the
only budget where a baseline wins. The counts are too small to read much into, but the top of
the model's ranking is not cleanly better than sorting by activity, and the top 3 to 5 accounts
are identical under both.

## What this means for peer-group scoring

Peer-group scoring drops from mandatory to optional. The case for it was that the score might be
finding busy accounts and nothing else, and that case is now closed by 2.09x at the operating
point.

The case that survives is different and narrower. Payment-count ranking still reaches 2.03%
recall on its own, the model reaches 4.25%, and 6,087 illicit accounts are still missed. Peer
grouping would not be a fix for a broken score. It would be an attempt to raise recall among
quiet launderers by scoring accounts against similar accounts rather than against the whole
population. That is worth doing on its merits, at a lower priority than it had before this test.

## Limitations

1. The baselines rank on activity computed from the same `int_edges` scope the model uses, so
   both inherit the exclusion of 591,212 self-transfers.
2. An account counts as illicit if it touched at least 1 laundering payment, which is the same
   broad label used throughout this project and favours no ranker in particular.
3. Ties in payment count are common at the low end. They are broken on `account_key`, so the
   deep end of the baseline curves is arbitrary within a tie band. This affects large budgets
   only, where all rankers converge anyway.
4. The data is synthetic. The 2.09x margin is a property of this dataset, not a bank.

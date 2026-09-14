# Results: 2,147 Alerts, 270 Real

Version 1.0, 2026-09-13. Every number comes from the evaluation models in this repo, rebuilt from scratch on that date. Data is synthetic (IBM HI-Small).

## The needle is 0.102% of the haystack

5,078,345 payments. 5,177 labeled laundering. 1 in 981.

Between different accounts it is 5,166 illicit payments out of 4,487,133 (0.115%). At account level, 6,357 of 422,734 active accounts touched a laundering payment (1.50%).

## Single rules are weak on their own

| Rule | Payments flagged | Share of payments | Precision | Lift over 0.115% |
|---|---|---|---|---|
| pass_through | 49,634 | 1.11% | 0.61% | 5.3 |
| structuring_band | 40,700 | 0.91% | 0.37% | 3.2 |
| structuring_24h | 80,420 | 1.79% | 0.13% | 1.1 |
| high_velocity | 509,124 | 11.35% | 0.13% | 1.1 |
| round_amount | 64 | 0.001% | 0% | 0 |
| cross_currency | 2,191 | 0.05% | 0% | 0 |

The best payment-level rule, pass-through, is right 0.61% of the time. Cross-currency and round-amount caught 0 laundering payments.

## Graph shapes carry the signal

At account level, scatter-gather flags 499 accounts and 342 are illicit: 68.5% precision, 45.6 times the base rate. Gather-scatter reaches 40.4% (lift 26.8) and 3-cycles 19.2% (lift 12.8). Fan-out is the weakest graph flag at 2.7% (lift 1.8), because paying many new people in 3 days is also what normal businesses do.

## The score trades recall for precision at every step

| Cutoff | Alerts | Precision | Recall |
|---|---|---|---|
| 11 | 32 | 75.0% | 0.38% |
| 8 | 459 | 19.2% | 1.38% |
| **6 (chosen)** | **2,147** | **12.6%** | **4.25%** |
| 3 | 25,670 | 4.9% | 19.85% |
| 1 | 51,310 | 4.2% | 34.01% |

The cutoff of 6 is the lowest score that keeps alerts within 1% of active accounts. At that point 270 of 2,147 alerts are real: 8.4 times better than picking accounts at random, and 2.09 times better than ranking the same accounts by payment count, which finds 129 at the same budget. The top 100 is 41% illicit; the top 10 is 8 of 10.

## Most attempts leave at least 1 fingerprint

At cutoff 6, 209 of 370 labeled attempts (56.5%) have at least 1 alerted account. Scatter-gather attempts are caught 88.6% of the time and gather-scatter 84.3%. Fan-out (41.7%), fan-in (42.5%) and cycles (42.6%) are harder. The 1,968 illicit payments that belong to no named pattern touch 3,227 accounts, and 37 of them (1.1%) are alerted.

## The false positives are the price, and volume sets it

1,877 of the 2,147 alerts are not laundering. The score rewards activity: alerted accounts have a median of 109 payments, against 19 for illicit accounts and 5 for unflagged accounts. 64 of the top 100 are in the busiest 1% of accounts, and rank 1 alone moved 52.76 billion USD across 168,672 payments. More payments mean more chances to trip a rule, so a busy legitimate business outranks a quiet mule. Recall is 4.25%. Part of that is the label: it counts any account that received a single laundering payment, and 1 inbound payment rarely looks like anything.

A monitoring team would not ship this score as is. It would compare accounts against peers of the same type and size, drop the 2 rules that caught nothing after confirming on held-out days, set thresholds on 2022-09-01 to 09-05 and measure on 09-06 to 09-10, and feed analyst decisions on reviewed alerts back into the weights.

**The rules do not find laundering. They decide which 2,147 accounts deserve a human first.**

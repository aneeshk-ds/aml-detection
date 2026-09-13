# AML Transaction Monitoring (DuckDB, SQL-first)

Rule-based and graph-based anti-money-laundering detection on 5,078,345 labeled synthetic
bank payments. The pipeline stages the raw files, flags payments with 6 monitoring rules,
finds 6 laundering shapes in the payment network, scores every account, and then measures
the flags against the ground-truth label.

Built to run at zero cost on a 2019 MacBook Air with 8 GB of RAM. Every detection rule and
typology is DuckDB SQL. No Python in the detection path.

## Results

Data: IBM Transactions for Anti Money Laundering, HI-Small set (Altman, Kaggle). 18 days,
518,581 accounts, 15 currencies. 5,177 payments are labeled laundering, which is 0.102%,
or 1 in 981.

At the chosen score cutoff of 6, on 422,734 active accounts:

| Measure | Value |
|---|---|
| Alerts | 2,147 (0.51% of active accounts) |
| True positives | 270 |
| False positives | 1,877 |
| Precision | 12.58% |
| Lift over the 1.50% account base rate | 8.4x |
| Recall | 4.25% |
| Precision in the top 100 | 41% |
| Labeled attempts with at least 1 alerted account | 209 of 370 (56.5%) |

The cutoff is chosen by alert volume, not by the label: it is the lowest score that keeps
alerts within 1% of active accounts.

Strongest single signal: the scatter-gather detector flags 499 accounts and 342 of them
touched laundering (68.5% precision, 45.6 times the base rate). Weakest: the cross-currency
and round-amount rules flagged 0 laundering payments.

Full numbers, including the precision and recall curve across 15 cutoffs and per-typology
recall, are in [outputs/metrics.md](outputs/metrics.md). The 7 acceptance criteria and the
evidence for each are in [outputs/acceptance_check.md](outputs/acceptance_check.md).

## Architecture

```
data/ (read-only CSVs)
  -> staging       stg_transactions, stg_accounts, stg_fx_rates, stg_patterns
  -> intermediate  int_transactions_usd, int_edges, int_pattern_transactions
  -> detection     6 rule models + det_transaction_flags
  -> graph         gr_pairs + 6 typology models
  -> scoring       sc_account_risk, sc_top100 -> outputs/ranked_accounts.csv
  -> evaluation    ev_cutoff_curve, ev_flag_performance, ev_typology_recall
```

26 models and 67 data tests, built with dbt-core 1.8.7, dbt-duckdb 1.8.4 and DuckDB 1.1.3.

Detection runs on 4,487,133 payments between 2 different accounts. 591,212 self-transfers
(11.64% of rows, 11 of them illicit) are excluded so they cannot inflate velocity, fan and
cycle counts.

## Detection rules (Phase 1)

| Rule | Logic | Payments flagged | Precision | Lift |
|---|---|---|---|---|
| pass_through | Receives at least 1,000 USD and sends 90% to 110% of it out inside 48 hours | 49,634 | 0.61% | 5.3 |
| structuring_band | Payment worth 9,000 to 9,999.99 USD, just under the reporting threshold | 40,700 | 0.37% | 3.2 |
| structuring_24h | 3 or more payments of 5,000 to 9,999.99 USD totalling over 10,000 USD in 24 hours | 80,420 | 0.13% | 1.1 |
| high_velocity | Rolling 24 hour outbound count above the 99th percentile of account peaks | 509,124 | 0.13% | 1.1 |
| round_amount | Exact multiple of 1,000 in the payment currency | 64 | 0% | 0 |
| cross_currency | Receiving currency differs from payment currency | 2,191 | 0% | 0 |

Transaction level, against a 0.115% base rate.

## Graph typologies (Phase 2)

Payments collapse into 647,939 directed account pairs. All detectors use a 72 hour window.

| Typology | Logic | Accounts flagged | Precision | Lift |
|---|---|---|---|---|
| scatter_gather | 3 or more intermediaries carry money from the same source to the same sink | 499 | 68.5% | 45.6 |
| gather_scatter | Fan-in followed by fan-out on the same account within 72 hours | 109 | 40.4% | 26.8 |
| cycle_3 | A pays B, B pays C, C pays A | 213 | 19.2% | 12.8 |
| cycle_2 | A pays B and B pays A | 3,934 | 9.4% | 6.3 |
| fan_in | 5 or more new senders inside 72 hours | 7,975 | 7.3% | 4.9 |
| fan_out | 5 or more new receivers inside 72 hours | 17,942 | 2.7% | 1.8 |

Account level, against a 1.50% base rate.

## Scoring (Phase 3)

risk_score is the weighted sum of an account's flags, maximum 23. Weights were set from
domain reasoning before any evaluation, never tuned on labels: 3 for pass_through, cycle_3,
scatter_gather and gather_scatter; 2 for structuring_24h, fan_out and fan_in; 1 for cycle_2,
structuring_band, high_velocity, round_amount and cross_currency.

Every threshold, window and weight is a variable in `dbt_project.yml`, so changing the
fan-out k or the alert budget is a 1 line edit and a rebuild.

## How to run

```bash
pip install -r requirements.txt
# put HI-Small_Trans.csv, HI-Small_accounts.csv and HI-Small_Patterns.txt in data/
dbt build --profiles-dir .
```

A full build takes about 250 seconds of model time on a 2 core machine, and 35 seconds for
the 67 tests.

## Repo layout

```
data/                 source CSVs, read-only, not in git
models/staging/       typed and keyed source models
models/intermediate/  USD conversion, detection scope, label linkage
models/detection/     Phase 1 rules
models/graph/         Phase 2 typologies
models/scoring/       Phase 3 risk score and ranked accounts
models/evaluation/    Phase 4 precision, recall, per-typology recall
tests/                7 custom data tests
outputs/              gate reports, metrics.md, ranked_accounts.csv, project explainer
writeup/              methodology.md and results.md
docs/build_brief.md   the original build brief
```

## Limitations

1. Recall is 4.25% at the chosen cutoff: 6,087 of 6,357 illicit accounts are never alerted.
2. The score follows activity. Alerted accounts have a median of 109 payments against 19 for
   illicit accounts, and 64 of the top 100 sit in the busiest 1% of accounts.
3. Cycle and scatter-gather timing is tested on account pairs, not on single payments, and
   SQL closes loops of exactly 2 or 3 accounts.
4. Thresholds and weights are hand-set and have not been validated on held-out days.
5. Bitcoin USD values are approximate: the rate implied by the data spans 10,000 to 20,000.
6. The data is synthetic, so none of these rates transfer directly to a real bank.

## Data quality tests

67 tests run on every build, including row-count parity with the source CSV, uniqueness on
every key, a check that no rule flags 0 or 100% of payments, a check that no graph detector
is empty, and a recomputation of every risk score from the weights.

## Author

Aneesh Kumar. Portfolio: https://aneeshk-ds.github.io

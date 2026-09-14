# Acceptance Check: definition of done

Checked 2026-09-13 against the 7 acceptance criteria in docs/build_brief.md. Every number below comes from a rebuild from scratch on this date, not from the earlier run.

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | dbt build runs clean, reported with row counts | PASS | Full rebuild with --full-refresh on 2026-09-13: 26 of 26 models OK, then 67 of 67 tests PASS. Extended 2026-09-14 with ev_baseline_comparison and 6 tests: 27 models, 73 of 73 tests PASS. stg_transactions 5,078,345 rows (5,177 illicit), int_edges 4,487,133 (5,166 illicit), sc_account_risk 422,734 accounts. Every headline number reproduced exactly |
| 2 | Phase 1 implements 5 or more rules, each with a flag rate | PASS | 6 rules: structuring_band 40,700 (0.907%), structuring_24h 80,420 (1.792%), pass_through 49,634 (1.106%), high_velocity 509,124 (11.346%), round_amount 64 (0.001%), cross_currency 2,191 (0.049%) |
| 3 | Phase 2 detects at least fan-out, fan-in, 2-cycle and 3-cycle, with counts | PASS | fan_out 17,942 accounts, fan_in 7,975 accounts, cycle_2 2,075 pairs, cycle_3 138 cycles, plus scatter_gather 80 routes and gather_scatter 109 accounts |
| 4 | A ranked top-100 suspicious-accounts table exists | PASS | outputs/ranked_accounts.csv, 100 rows, 22 columns, all populated (not_null tests plus assert_top100_has_100_rows). 41 of the 100 touched laundering |
| 5 | outputs/metrics.md reports precision, recall and per-typology recall with real numbers and 1 honest paragraph on weaknesses | PASS | At the chosen cutoff 6: 2,147 alerts, 270 TP, 1,877 FP, 6,087 FN, precision 12.58%, recall 4.25%, lift 8.36. Per-typology recall for 8 typologies plus the unclassified group. Section "Where this approach is weak" |
| 6 | A methodology note and a results note exist, following the formatting rules | PASS | writeup/methodology.md and writeup/results.md. Lint over every generated file: 0 em dashes, 0 exclamation marks, 0 banned words |
| 7 | No source CSV was modified, all outputs under outputs/ | PASS | The 3 files in data/ still carry their download timestamp of 2025-07-08 and are read-only inputs. Generated results live in outputs/ and writeup/ |

## Per-typology recall at the chosen cutoff

| Typology | Attempts | Attempts alerted | Attempt recall | Accounts | Accounts alerted | Account recall |
|---|---|---|---|---|---|---|
| BIPARTITE | 49 | 28 | 57.1% | 491 | 28 | 5.7% |
| CYCLE | 54 | 23 | 42.6% | 271 | 35 | 12.9% |
| FAN-IN | 40 | 17 | 42.5% | 338 | 29 | 8.6% |
| FAN-OUT | 48 | 20 | 41.7% | 359 | 30 | 8.4% |
| GATHER-SCATTER | 51 | 43 | 84.3% | 685 | 58 | 8.5% |
| RANDOM | 41 | 16 | 39.0% | 211 | 23 | 10.9% |
| SCATTER-GATHER | 44 | 39 | 88.6% | 369 | 111 | 30.1% |
| STACK | 43 | 23 | 53.5% | 663 | 37 | 5.6% |
| NOT CLASSIFIED | n/a | n/a | n/a | 3,227 | 37 | 1.1% |

## Not part of the criteria, still open

- Phase 5 (Python, networkx, Tableau) has not started. The brief marks it optional and gates it on An saying Python is ready.
- Thresholds and weights have not been validated on held-out days.

## Machine note

On 2026-09-13 the project folder on the external drive wrote at 1.2 MB/s (reads were 28 MB/s), so building the database inside the folder timed out. The rebuild used the `vm` target added to profiles.yml, which puts the database on local disk and leaves outputs in the folder. Same SQL, same results.
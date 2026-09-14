# Time-based holdout: do the thresholds hold on days they were never seen on?

Run date: 2026-09-14. Thresholds set on 2022-09-01 to 09-05, reported on 2022-09-06 to 09-10.
Every number comes from rebuilding the full detection, graph and scoring pipeline separately on
each window, using the `window_start` and `window_end` variables in `dbt_project.yml`.

## What this proves, and what it does not

Two parameters in this pipeline are derived from data rather than from domain reasoning: the
velocity threshold, which is the 99th percentile of per-account peak 24 hour outbound counts,
and the alert cutoff, which is the lowest score keeping alerts within 1% of active accounts.
Those two are the only things a holdout can genuinely hold out here.

The other 10 thresholds and all 12 weights were set from domain reasoning and never touched a
label. A holdout cannot detect label overfitting in parameters that were never fitted to labels.
What it can detect is whether the same fixed rules keep working on days they were not designed
against, which is what this measures.

This is a temporal stability test. It is not an independent-sample test, for the reason in the
overlap section below.

## The split, and the 8 days that were thrown away

The dataset spans 2022-09-01 to 2022-09-18, but only the first 10 days are usable. From 09-11
the legitimate payment stream stops and only the terminal legs of laundering chains continue:
715 payments across 8 days, 652 of them illicit, an illicit rate between 87% and 100% against
0.101% in the dense period. That is a property of the data generator, not of any bank. Those 8
days are excluded from both windows. Excluding them removes 12.6% of all illicit payments.

| Window | Days | Payments | Illicit payments | Accounts | Illicit accounts | Base rate |
|---|---|---|---|---|---|---|
| Train | 09-01 to 09-05 | 2,224,847 | 1,994 | 404,273 | 2,799 | 0.692% |
| Test | 09-06 to 09-10 | 2,261,571 | 2,520 | 372,889 | 3,357 | 0.900% |

Payment volumes match within 2%. The test window carries a 30% higher account base rate, so
precision is not comparable across the two windows and lift is. Lift leads every comparison below.

## Results

| Measure | Train (09-01 to 09-05) | Test (09-06 to 09-10), cutoff frozen at 6 |
|---|---|---|
| Velocity threshold, derived per window | 20 | 20 |
| Cutoff chosen by the 1% budget rule | 6 | 4 |
| Alerts at cutoff 6 | 1,470 (0.364%) | 715 (0.192%) |
| True positives | 82 | 74 |
| False positives | 1,388 | 641 |
| Precision | 5.58% | 10.35% |
| Recall | 2.93% | 2.20% |
| **Lift over that window's base rate** | **8.06** | **11.50** |
| True positives vs payment-count ranking | 82 vs 42 (1.95x) | 74 vs 49 (1.51x) |

Full period, for reference: cutoff 6, 2,147 alerts, 270 true positives, 12.58% precision, 4.25%
recall, 8.4 lift, 2.09x over payment-count ranking.

## What holds

The rules transfer to unseen days. At the frozen cutoff of 6, lift rises from 8.06 on train to
11.50 on test. Performance did not degrade on days the thresholds were never set against, which
is the result this test existed to check.

The velocity threshold is the stronger finding. It is recomputed independently inside each
window and lands on 20 in the train window, 20 in the test window, and 20 over the full period.
The one data-derived detection parameter does not move when the data underneath it changes.

## What does not hold

The cutoff selection rule is not stable. It picks 6 on train and 4 on test. The rule is defined
relative to alert volume as a share of active accounts, and the test window has 7.8% fewer
accounts and far fewer high-scoring ones, so 715 alerts at cutoff 6 uses only 0.192% of the 1%
budget and the rule reaches further down to spend it. At the cutoff the rule picks on test,
lift falls from 11.50 to 6.34 and precision falls to 5.70%, though recall more than doubles to
5.18%.

This matters operationally. A cutoff re-derived each period would have moved the operating point
between these two windows without anyone deciding to move it. The fix is to pin the cutoff once
and review it deliberately, not to recompute it every cycle.

The margin over the activity baseline also narrows on test, from 1.95x on train to 1.51x. It
stays above 1 in both windows and in the full period, but 1.51x is the weakest reading of the
three and is the honest floor for that claim.

## The overlap caveat, which limits every claim above

The windows are separated in time but not in population.

| Accounts | Count |
|---|---|
| Active in train only | 49,767 |
| Active in test only | 18,383 |
| Active in both windows | 354,506 |

83.9% of accounts appear in both windows, and 5,185 of 6,357 illicit accounts (81.6%) appear in
both. A laundering ring active on 09-04 is very likely still active on 09-08. So the test window
is not an independent sample; it is a later slice of largely the same entities and the same
laundering attempts.

That is the honest reading: these rules keep working on later days for accounts they have
already seen. This test does not show they would work on a different bank, a different period,
or an unseen population, and nothing here should be described as cross-validation.

## Limitations

1. Cold start. The 24, 48 and 72 hour detectors see no history in the first hours of each
   window. This affects both windows symmetrically, since both begin cold, but it understates
   detections near each boundary and truncates the opening legs of patterns spanning 09-06.
2. Recall in each window (2.93% and 2.20%) is below the full-period 4.25%, mostly because
   splitting the period cuts multi-day patterns in half and each window is graded only against
   the attempts inside it.
3. 12.6% of illicit payments sit in the excluded 09-11 to 09-18 tail and are graded in neither
   window.
4. The velocity threshold was compared across windows rather than frozen from train. Freezing it
   would require a variable inside `det_high_velocity`, and that model is one of the 11 awaiting
   a rewrite, so it was left untouched. Since the threshold independently lands on 20 in both
   windows, comparing it is the stronger evidence anyway.
5. The data is synthetic. None of these rates transfer to a real bank.

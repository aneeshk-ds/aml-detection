# Per-alert case files

Run date: 2026-09-14. Model: `models/scoring/sc_alert_evidence.sql`. Renderer:
`scripts/render_case_file.py`. Examples: `outputs/case_files/`.

## What this is

The pipeline produced 2,147 account numbers and a score. A score says an account is suspicious.
It does not say why, or what to look at, and an alert an investigator cannot act on is not worth
raising. This closes that gap.

`sc_alert_evidence` holds 51,130 evidence rows covering all 2,147 alerted accounts, at a median
of 19 rows per account and a maximum of 121. Every alerted account is covered, and a data test
fails the build if any alert is missing evidence or any evidence row belongs to a non-alert.

Four evidence classes per account:

| Class | What it answers |
|---|---|
| score | Which signals fired and what each contributed to the score |
| transaction | The specific payments that tripped each rule, with time, amount, counterparty and format, capped at 20 per rule |
| network | The account's role in each typology and who sits on the other side of it |
| profile | How active the account is, which is the context for judging everything above |

The table carries no laundering label, and neither does any rendered file. This is the alert
exactly as an analyst would receive it, the same convention `sc_top100` follows. The renderer
will produce a file for any of the 2,147 by rank or by account key.

## The four examples, and how each was chosen

Ranks 1, 2 and 3 were chosen by rank alone, before any label was consulted. All three turn out
to be labeled laundering, which is not a surprise given 8 of the top 10 are, and is not evidence
that the format works on anything else.

So a fourth was added deliberately: the highest-ranked account that is not labeled laundering,
which sits at rank 8. Selecting it required reading the label, and that is stated here rather
than presented as a blind pick. An analyst spends most of their time on false positives, 1,877
of the 2,147 alerts here, so a set of examples containing only hits would misrepresent the job.

| File | Rank | Score | Selected by | Labeled laundering |
|---|---|---|---|---|
| case_70_100428660.md | 1 | 15 | rank | yes |
| case_121_8000E1590.md | 2 | 15 | rank | yes |
| case_222_811D80C30.md | 3 | 15 | rank | yes |
| case_1729_802274090.md | 8 | 12 | label, as the top false positive | no |

## What the case files exposed

Opening rank 1 is the finding. That account sent 168,672 payments and received 1,084, moving
52.76 billion USD. An account at that scale is an institutional hub, and it will touch a
laundering payment by volume alone. It counts as a true positive because the account label is
broad: touching 1 laundering payment marks the account. So the single highest-ranked alert in
the system is correct by the label and close to useless to an investigator.

Compare the false positive at rank 8: 58 payments sent, 47 received, 8.37 million USD. That
profile is far more typical of an account worth an hour of an analyst's time, and the score
ranks it below the hub.

The score-only view cannot show this. Both accounts are just a rank and a number. The profile
row is what makes the difference visible in one line, and it is the cheapest thing in the whole
evidence table.

This sharpens the activity criticism already in metrics.md. The problem is not only that the
score correlates with activity. It is that at the very top of the queue, the label agrees with
the score for a reason that has nothing to do with detection quality.

## Limitations

1. Transaction evidence is capped at 20 payments per rule per account. Accounts that tripped a
   rule hundreds of times show the 20 largest by USD, not all of them.
2. The `fan_out` and `fan_in` detectors record a count and a time but not which counterparties
   were new, so their evidence rows carry no counterparty. Recovering those would mean changing
   the detectors, which are awaiting a rewrite.
3. The alert set is derived from the cutoff the evaluation layer chooses. The holdout showed
   that rule is unstable across periods, so pinning the cutoff explicitly would make the
   evidence table's population stable too.
4. There is no disposition field yet. Recording analyst outcomes is what would later allow
   weights to be learned from reviewed cases instead of set by hand.

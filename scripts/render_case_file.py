"""Render the analyst case file for one alerted account.

Usage:
    python3 scripts/render_case_file.py --rank 1
    python3 scripts/render_case_file.py --account <account_key>

Reads sc_alert_evidence, which carries no laundering label on purpose: this renders the
alert exactly as an investigator would receive it. Writes outputs/case_files/.
"""
import argparse
import os
import re
import sys

import duckdb

NEXT_STEPS = {
    "pass_through":     "Confirm whether the inbound and outbound legs have a business reason. Money in and straight back out is the shape, not the proof.",
    "structuring_band": "Check whether payments sit just under the 10,000 reporting threshold repeatedly, or once by coincidence.",
    "structuring_24h":  "Look at whether the same counterparty receives the split payments, which separates structuring from ordinary batching.",
    "high_velocity":    "Compare the burst against this account's own history. A payroll or settlement account is busy by design.",
    "round_amount":     "Weak on its own. Treat as supporting detail only.",
    "cross_currency":   "Weak on its own. Treat as supporting detail only.",
    "fan_out":          "Identify whether the new receivers are related to each other. Unrelated new receivers in 72 hours is the concern.",
    "fan_in":           "Identify whether the new senders are related. Many unrelated senders into one account is a collection point.",
    "cycle_2":          "Reciprocal payments can be netting between trading partners. Check whether the amounts offset.",
    "cycle_3":          "A closed loop of three accounts has few legitimate explanations. Prioritise this one.",
    "gather_scatter":   "Funds collected then redistributed within 72 hours. Check whether the receivers differ from the senders.",
    "scatter_gather":   "This account sits on a route where several intermediaries carry funds between the same two endpoints. Prioritise this one.",
}


def fetch(con, account_key):
    meta = con.execute(
        "select a.bank_name, a.entity_name from stg_accounts a where a.account_key = ?",
        [account_key],
    ).fetchone()
    rows = con.execute(
        """select risk_rank, risk_score, evidence_class, evidence_type, txn_id,
                  event_ts, amount_usd, counterparty, detail
           from sc_alert_evidence where account_key = ?
           order by evidence_class, evidence_type, event_ts""",
        [account_key],
    ).fetchall()
    total = con.execute("select count(distinct account_key) from sc_alert_evidence").fetchone()[0]
    return meta, rows, total


def render(account_key, meta, rows, total):
    rank, score = rows[0][0], rows[0][1]
    bank, entity = (meta or ("unknown", "unknown"))
    out = []
    out.append("# Case file: account %s" % account_key)
    out.append("")
    out.append("Alert rank %d of %d. Risk score %d of a possible 23." % (rank, total, score))
    out.append("")
    out.append("Bank: %s. Entity: %s." % (bank, entity))
    out.append("")
    out.append("Generated from `sc_alert_evidence` by `scripts/render_case_file.py`. No laundering")
    out.append("label is used or shown anywhere in this file.")
    out.append("")

    fired = [r for r in rows if r[2] == "score"]
    out.append("## Why this account alerted")
    out.append("")
    out.append("| Signal | Contribution |")
    out.append("|---|---|")
    for r in fired:
        out.append("| %s | %s |" % (r[3], r[8].replace("contributed ", "").replace(" to the score", "")))
    out.append("")

    prof = [r for r in rows if r[2] == "profile"]
    if prof:
        out.append("## Account activity")
        out.append("")
        out.append("Payments: %s. Total moved: %s USD." % (prof[0][8], "{:,.2f}".format(prof[0][6] or 0)))
        out.append("")
        out.append("This is the context for everything below. A high count is not itself suspicious")
        out.append("if it is normal for this account.")
        out.append("")

    txns = [r for r in rows if r[2] == "transaction"]
    if txns:
        out.append("## Transaction evidence")
        out.append("")
        for et in sorted({r[3] for r in txns}):
            sub = [r for r in txns if r[3] == et]
            out.append("### %s (%d payments shown)" % (et, len(sub)))
            out.append("")
            out.append("| Time | Amount USD | Counterparty | Detail |")
            out.append("|---|---|---|---|")
            for r in sub[:10]:
                out.append("| %s | %s | %s | %s |" % (
                    r[5], "{:,.2f}".format(r[6] or 0), r[7] or "", r[8] or ""))
            if len(sub) > 10:
                out.append("")
                out.append("%d further payments in `sc_alert_evidence`." % (len(sub) - 10))
            out.append("")

    net = [r for r in rows if r[2] == "network"]
    if net:
        out.append("## Network evidence")
        out.append("")
        for et in sorted({r[3] for r in net}):
            sub = [r for r in net if r[3] == et]
            out.append("### %s" % et)
            out.append("")
            has_cp = any(r[7] for r in sub)
            if has_cp:
                out.append("| Time | Counterparty | What the detector saw |")
                out.append("|---|---|---|")
            else:
                out.append("| Time | What the detector saw |")
                out.append("|---|---|")
            for r in sub[:10]:
                if has_cp:
                    out.append("| %s | %s | %s |" % (r[5], r[7] or "", r[8] or ""))
                else:
                    out.append("| %s | %s |" % (r[5], r[8] or ""))
            if len(sub) > 10:
                out.append("")
                out.append("%d further links in `sc_alert_evidence`." % (len(sub) - 10))
            out.append("")

    out.append("## What to check next")
    out.append("")
    for r in fired:
        step = NEXT_STEPS.get(r[3])
        if step:
            out.append("**%s.** %s" % (r[3], step))
            out.append("")
    out.append("## Disposition")
    out.append("")
    out.append("Escalate, clear, or request more information. Recording the outcome here is what")
    out.append("would later let weights be learned from reviewed cases instead of set by hand.")
    out.append("")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rank", type=int)
    ap.add_argument("--account")
    ap.add_argument("--db", default="aml.duckdb")
    ap.add_argument("--outdir", default="outputs/case_files")
    a = ap.parse_args()
    if not a.rank and not a.account:
        sys.exit("give --rank or --account")

    con = duckdb.connect(a.db)
    key = a.account
    if key is None:
        got = con.execute(
            "select distinct account_key from sc_alert_evidence where risk_rank = ?", [a.rank]
        ).fetchone()
        if not got:
            sys.exit("no alerted account at rank %d" % a.rank)
        key = got[0]

    meta, rows, total = fetch(con, key)
    con.close()
    if not rows:
        sys.exit("no evidence for account %s" % key)

    os.makedirs(a.outdir, exist_ok=True)
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", key)
    path = os.path.join(a.outdir, "case_%s.md" % safe)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(render(key, meta, rows, total))
    print("wrote %s (%d evidence rows)" % (path, len(rows)))


if __name__ == "__main__":
    main()

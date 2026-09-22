"""Generate the small synthetic fixture that CI builds the pipeline against.

The fixture is not random. Every detector in the project needs something to find, so
each pattern is planted deliberately: a fan-out, a fan-in, a 2-cycle, a 3-cycle, a
gather-scatter and a scatter-gather route, plus payments engineered to trip each of the
six transaction rules. That makes CI a real end-to-end check rather than a syntax check.

It contains no IBM or Kaggle data. Every row here is invented, which is why it can be
committed when the real source data cannot.

Usage:
    python3 scripts/make_ci_fixture.py
Writes ci/fixture/HI-Small_Trans.csv, HI-Small_accounts.csv, HI-Small_Patterns.txt
"""
import os
import random
from datetime import datetime, timedelta

random.seed(42)
OUT = "ci/fixture"
T0 = datetime(2022, 9, 1, 0, 0)
N_ACCOUNTS = 160

rows = []            # each: dict
patterns = []        # each: (typology, detail, [row index, ...])


def acct(i):
    bank = 1 if i < 60 else (10 if i < 120 else 20)
    return bank, "8000%05d" % i


def key(i):
    b, a = acct(i)
    return "%d_%s" % (b, a)


def pay(minutes, src, dst, paid, recv=None, pay_cur="US Dollar", recv_cur=None,
        fmt="ACH", illicit=0):
    """Append one payment and return the row itself, so later sorting cannot invalidate it."""
    recv = paid if recv is None else recv
    recv_cur = pay_cur if recv_cur is None else recv_cur
    sb, sa = acct(src)
    db, da = acct(dst)
    rows.append({
        "ts": T0 + timedelta(minutes=minutes),
        "from_bank": sb, "from_acct": sa, "to_bank": db, "to_acct": da,
        "amt_recv": recv, "recv_cur": recv_cur,
        "amt_paid": paid, "pay_cur": pay_cur,
        "fmt": fmt, "illicit": illicit,
    })
    return rows[-1]


# ---------------------------------------------------------------- benign filler
# Ordinary traffic so no rule flags 100% of payments. Amounts avoid every band the
# rules look at: never a multiple of 1000, never 5000 or above.
fmts = ["ACH", "Cheque", "Credit Card", "Wire"]
for i in range(600):
    src = random.randint(20, 159)
    dst = random.randint(20, 159)
    while dst == src:
        dst = random.randint(20, 159)
    amt = round(random.uniform(50, 4800), 2)
    if amt % 1000 == 0:
        amt += 0.37
    pay(random.randint(0, 7200), src, dst, amt, fmt=random.choice(fmts))

# ---------------------------------------------------------------- rule triggers
# round_amount: at least 1000 and an exact multiple of 1000
for n, amount in enumerate([3000.0, 5000.0, 10000.0, 2000.0, 7000.0]):
    pay(100 + n * 60, 20 + n, 50 + n, amount)

# cross_currency, which also gives stg_fx_rates the pairs it derives the Euro rate from
for n in range(20):
    pay(200 + n * 30, 25 + (n % 10), 60 + (n % 10),
        1000.0, recv=1080.0, pay_cur="Euro", recv_cur="US Dollar")

# structuring_band: 9000 up to but not including 10000 USD
for n, amount in enumerate([9200.50, 9500.75, 9800.25, 9050.10]):
    pay(300 + n * 45, 35 + n, 70 + n, amount)

# structuring_24h: 3 or more payments of 5000 to 9999.99 from one sender inside 24h,
# totalling over 10000
for n, amount in enumerate([6000.10, 6500.20, 7000.30, 5500.40]):
    pay(400 + n * 120, 40, 71 + n, amount)

# high_velocity: one clear outlier so the 99th percentile of account peaks sits below it
for n in range(40):
    pay(500 + n * 20, 41, 72 + (n % 40), round(random.uniform(200, 900), 2))

# pass_through: receives at least 1000 and sends 90 to 110 percent of it back out in 48h
pay(600, 46, 45, 5000.0)
pay(960, 45, 47, 4900.0)

# ---------------------------------------------------------------- planted typologies
# FAN-OUT: one sender reaches 6 new counterparties inside 72h (fan_k is 5)
idx = [pay(1000 + n * 200, 100, 101 + n, round(3000 + n * 137.11, 2), illicit=1)
       for n in range(6)]
patterns.append(("FAN-OUT", "  Max 6-degree Fan-Out", idx))

# FAN-IN: 6 senders reach one receiver inside 72h
idx = [pay(1200 + n * 200, 110 + n, 116, round(2500 + n * 211.07, 2), illicit=1)
       for n in range(6)]
patterns.append(("FAN-IN", "  Max 6-degree Fan-In", idx))

# CYCLE of 2: A pays B and B pays A inside the 72h window
idx = [pay(1500, 120, 121, 4321.11, illicit=1),
       pay(1800, 121, 120, 4210.22, illicit=1)]
patterns.append(("CYCLE", "  Cycle of length 2", idx))

# CYCLE of 3: A -> B -> C -> A. Amounts are set so each leg also reads as pass-through,
# which puts these three accounts on exactly the pinned alert cutoff of 6
# (cycle_3 weight 3 plus pass_through weight 3).
idx = [pay(2000, 132, 130, 5000.0, illicit=1),
       pay(2180, 130, 131, 4950.0, illicit=1),
       pay(2360, 131, 132, 4900.0, illicit=1)]
patterns.append(("CYCLE", "  Cycle of length 3", idx))

# GATHER-SCATTER: 5 senders into one account, then that account out to 5 others
idx = [pay(3000 + n * 120, 141 + n, 140, round(2000 + n * 91.13, 2), illicit=1)
       for n in range(5)]
idx += [pay(3800 + n * 120, 140, 146 + n, round(1900 + n * 87.19, 2), illicit=1)
        for n in range(5)]
patterns.append(("GATHER-SCATTER", "  Gather then scatter", idx))

# SCATTER-GATHER: one source through 4 intermediaries into one sink
idx = [pay(4000 + n * 90, 151, 152 + n, round(2600 + n * 53.41, 2), illicit=1)
       for n in range(4)]
idx += [pay(4600 + n * 90, 152 + n, 156, round(2550 + n * 49.17, 2), illicit=1)
        for n in range(4)]
patterns.append(("SCATTER-GATHER", "  4 intermediaries between one source and one sink", idx))


# ---------------------------------------------------------------- write the files
def line(r):
    return "%s,%s,%s,%s,%s,%.2f,%s,%.2f,%s,%s,%d" % (
        r["ts"].strftime("%Y/%m/%d %H:%M"),
        r["from_bank"], r["from_acct"], r["to_bank"], r["to_acct"],
        r["amt_recv"], r["recv_cur"], r["amt_paid"], r["pay_cur"],
        r["fmt"], r["illicit"])


os.makedirs(OUT, exist_ok=True)

rows.sort(key=lambda r: r["ts"])
with open(os.path.join(OUT, "HI-Small_Trans.csv"), "w", encoding="utf-8") as fh:
    fh.write("Timestamp,From Bank,Account,To Bank,Account,Amount Received,"
             "Receiving Currency,Amount Paid,Payment Currency,Payment Format,Is Laundering\n")
    for r in rows:
        fh.write(line(r) + "\n")

with open(os.path.join(OUT, "HI-Small_accounts.csv"), "w", encoding="utf-8") as fh:
    fh.write("Bank Name,Bank ID,Account Number,Entity ID,Entity Name\n")
    for i in range(N_ACCOUNTS):
        b, a = acct(i)
        fh.write("Test Bank #%d,%d,%s,800%06d,Corporation #%d\n" % (b, b, a, i, 1000 + i))

with open(os.path.join(OUT, "HI-Small_Patterns.txt"), "w", encoding="utf-8") as fh:
    for typology, detail, idxs in patterns:
        fh.write("BEGIN LAUNDERING ATTEMPT - %s:%s\n" % (typology, detail))
        for r in sorted(idxs, key=lambda r: r["ts"]):
            fh.write(line(r) + "\n")
        fh.write("END LAUNDERING ATTEMPT - %s\n" % typology)

print("wrote %d payments, %d accounts, %d laundering attempts"
      % (len(rows), N_ACCOUNTS, len(patterns)))

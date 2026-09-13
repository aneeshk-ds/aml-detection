-- Rule: payment is an exact multiple of round_amount_unit in the currency it was paid in.
-- Grain: 1 row per flagged transaction.
SELECT
    txn_id,
    from_account_key,
    txn_ts,
    amount_paid,
    payment_currency
FROM {{ ref('int_edges') }}
WHERE amount_paid >= {{ var('round_amount_unit') }}
  AND amount_paid % {{ var('round_amount_unit') }} = 0

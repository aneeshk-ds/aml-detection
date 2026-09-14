-- Fails if any alerted account is missing from the evidence table, or if the evidence table
-- carries an account that is not an alert. An alert an investigator cannot open is useless,
-- and evidence for a non-alert means the two are describing different populations.
with chosen as (
    select cutoff from {{ ref('ev_cutoff_curve') }} where is_chosen_cutoff
),
alerts as (
    select r.account_key
    from {{ ref('sc_account_risk') }} r
    cross join chosen c
    where r.risk_score >= c.cutoff
),
evidence as (
    select distinct account_key from {{ ref('sc_alert_evidence') }}
)
select 'alert without evidence' as problem, account_key from (select account_key from alerts except select account_key from evidence)
union all
select 'evidence without alert', account_key from (select account_key from evidence except select account_key from alerts)

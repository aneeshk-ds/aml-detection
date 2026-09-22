# Model lineage

Generated from `target/manifest.json`, so it matches the built DAG rather than a hand
drawing. 28 models across 6 layers, 66 dependencies.

Regenerate with `dbt parse` followed by `python3 scripts/render_lineage.py`.

```mermaid
graph LR
  subgraph staging
    stg_accounts[stg_accounts]
    stg_fx_rates[stg_fx_rates]
    stg_patterns[stg_patterns]
    stg_transactions[stg_transactions]
  end
  subgraph intermediate
    int_edges[int_edges]
    int_pattern_transactions[int_pattern_transactions]
    int_transactions_usd[int_transactions_usd]
  end
  subgraph detection
    det_cross_currency[det_cross_currency]
    det_high_velocity[det_high_velocity]
    det_pass_through[det_pass_through]
    det_round_amount[det_round_amount]
    det_structuring_24h[det_structuring_24h]
    det_structuring_band[det_structuring_band]
    det_transaction_flags[det_transaction_flags]
  end
  subgraph graph
    gr_cycle_2[gr_cycle_2]
    gr_cycle_3[gr_cycle_3]
    gr_fan_in[gr_fan_in]
    gr_fan_out[gr_fan_out]
    gr_gather_scatter[gr_gather_scatter]
    gr_pairs[gr_pairs]
    gr_scatter_gather[gr_scatter_gather]
  end
  subgraph scoring
    sc_account_risk[sc_account_risk]
    sc_alert_evidence[sc_alert_evidence]
    sc_top100[sc_top100]
  end
  subgraph evaluation
    ev_baseline_comparison[ev_baseline_comparison]
    ev_cutoff_curve[ev_cutoff_curve]
    ev_flag_performance[ev_flag_performance]
    ev_typology_recall[ev_typology_recall]
  end
  det_cross_currency --> det_transaction_flags
  det_cross_currency --> sc_account_risk
  det_cross_currency --> sc_alert_evidence
  det_high_velocity --> det_transaction_flags
  det_high_velocity --> sc_account_risk
  det_high_velocity --> sc_alert_evidence
  det_pass_through --> det_transaction_flags
  det_pass_through --> sc_account_risk
  det_pass_through --> sc_alert_evidence
  det_round_amount --> det_transaction_flags
  det_round_amount --> sc_account_risk
  det_round_amount --> sc_alert_evidence
  det_structuring_24h --> det_transaction_flags
  det_structuring_24h --> sc_account_risk
  det_structuring_24h --> sc_alert_evidence
  det_structuring_band --> det_transaction_flags
  det_structuring_band --> sc_account_risk
  det_structuring_band --> sc_alert_evidence
  det_transaction_flags --> ev_flag_performance
  ev_cutoff_curve --> ev_baseline_comparison
  ev_cutoff_curve --> ev_typology_recall
  ev_cutoff_curve --> sc_alert_evidence
  gr_cycle_2 --> sc_account_risk
  gr_cycle_2 --> sc_alert_evidence
  gr_cycle_3 --> sc_account_risk
  gr_cycle_3 --> sc_alert_evidence
  gr_fan_in --> gr_gather_scatter
  gr_fan_in --> sc_account_risk
  gr_fan_in --> sc_alert_evidence
  gr_fan_out --> gr_gather_scatter
  gr_fan_out --> sc_account_risk
  gr_fan_out --> sc_alert_evidence
  gr_gather_scatter --> sc_account_risk
  gr_gather_scatter --> sc_alert_evidence
  gr_pairs --> gr_cycle_2
  gr_pairs --> gr_cycle_3
  gr_pairs --> gr_fan_in
  gr_pairs --> gr_fan_out
  gr_pairs --> gr_scatter_gather
  gr_scatter_gather --> sc_account_risk
  gr_scatter_gather --> sc_alert_evidence
  int_edges --> det_cross_currency
  int_edges --> det_high_velocity
  int_edges --> det_pass_through
  int_edges --> det_round_amount
  int_edges --> det_structuring_24h
  int_edges --> det_structuring_band
  int_edges --> det_transaction_flags
  int_edges --> ev_typology_recall
  int_edges --> gr_pairs
  int_edges --> sc_account_risk
  int_edges --> sc_alert_evidence
  int_pattern_transactions --> ev_typology_recall
  int_transactions_usd --> int_edges
  sc_account_risk --> ev_baseline_comparison
  sc_account_risk --> ev_cutoff_curve
  sc_account_risk --> ev_flag_performance
  sc_account_risk --> ev_typology_recall
  sc_account_risk --> sc_alert_evidence
  sc_account_risk --> sc_top100
  stg_accounts --> sc_top100
  stg_fx_rates --> int_transactions_usd
  stg_patterns --> int_pattern_transactions
  stg_transactions --> int_pattern_transactions
  stg_transactions --> int_transactions_usd
  stg_transactions --> stg_fx_rates
```

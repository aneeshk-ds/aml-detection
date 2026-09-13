-- Fails if any account's risk_score differs from the weighted sum of its flags using the
-- weights in dbt_project.yml.
{% set flags = ['structuring_band', 'structuring_24h', 'pass_through', 'high_velocity', 'round_amount', 'cross_currency',
                'fan_out', 'fan_in', 'gather_scatter', 'cycle_2', 'cycle_3', 'scatter_gather'] %}
select account_key, risk_score
from {{ ref('sc_account_risk') }}
where risk_score <> (
    {% for f in flags %}
    {{ var('weight_' ~ f) }} * f_{{ f }}{{ " +" if not loop.last }}
    {% endfor %}
)

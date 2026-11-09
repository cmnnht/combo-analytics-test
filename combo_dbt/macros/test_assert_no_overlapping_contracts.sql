{% test assert_no_overlapping_contracts(model, membership_id_col='membership_id', contract_id_col='user_contract_id', start_col='contract_start', end_col='contract_end') %}

{{ config(store_failures=true) }}

WITH contract_range AS (
    SELECT
        {{ membership_id_col }} AS membership_id,
        {{ contract_id_col }} AS user_contract_id,
        {{ start_col }} AS contract_start,
        COALESCE({{ end_col }}, CAST('2050-01-01' AS DATE)) AS contract_end
    FROM {{ model }}
)

SELECT
    c1.membership_id,
    c1.user_contract_id AS first_contract_id,
    c2.user_contract_id AS overlapping_contract_id,
    c1.contract_start AS start_contrat_1,
    c2.contract_start AS start_contrat_2,
    c1.contract_end AS end_contrat_1,
    c2.contract_end AS end_contract_2
FROM contract_range c1
INNER JOIN contract_range c2 
    ON c1.membership_id = c2.membership_id
    AND c1.user_contract_id < c2.user_contract_id 
WHERE 
    c1.contract_start < c2.contract_end 
    AND c1.contract_end > c2.contract_start

{% endtest %}

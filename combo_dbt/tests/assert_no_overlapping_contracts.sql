-- Ce test échoue si un employé a plus d'un contrat actif sur la même période.
{{ config(
    severity='warn',
    store_failures=true
) }}

WITH contract_range AS (
    SELECT
        membership_id,
        user_contract_id,
        contract_start,
        -- Si contract_end est null (CDI en cours), on attribue une date lointaine (ex: année 2050)
        COALESCE(contract_end, cast('2050-01-01' as date)) AS contract_end,
        contract_type
    FROM {{ ref('stg_raw__user_contracts') }}
)

SELECT
    c1.membership_id,
    c1.user_contract_id AS first_contract_id,
    c2.user_contract_id AS overlapping_contract_id,
    c1.contract_start AS start_contrat_1,
    c2.contract_start AS start_contrat_2,
    c1.contract_end AS end_contrat_1,
    c2.contract_end AS end_contract_2,
    c1.contract_type AS contract_type_1,
    c2.contract_type AS contract_type_2
FROM contract_range c1
INNER JOIN contract_range c2 
    ON c1.membership_id = c2.membership_id
    -- Évite de comparer un contrat avec lui-même
    AND c1.user_contract_id < c2.user_contract_id 
WHERE (c1.contract_start < c2.contract_end AND c1.contract_end > c2.contract_start)

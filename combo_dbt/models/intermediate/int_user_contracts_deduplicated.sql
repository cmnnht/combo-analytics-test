{{ config(materialized='view') }}

WITH contracts_with_priority AS (
    SELECT 
        user_contract_id,
        location_id,
        contract_start,
        contract_end,
        account_id,
        membership_id,
        contract_type,
        ROW_NUMBER() OVER (
            PARTITION BY membership_id
            ORDER BY 
                CASE contract_type
                    WHEN 'CDI' THEN 1
                    WHEN 'apprentissage' THEN 2
                    WHEN 'CDD' THEN 3
                    WHEN 'seasonal' THEN 4
                    ELSE 5
                END,
                contract_start DESC
        ) AS rank_priority,
        DATE_TRUNC('week', contract_start) AS contract_start_week,
        DATE_TRUNC('week', contract_end) AS contract_end_week
    FROM {{ ref('stg_raw__user_contracts') }}
    WHERE membership_id IN (SELECT DISTINCT membership_id FROM {{ ref('stg_raw__memberships') }})
        AND location_id IN (SELECT DISTINCT location_id FROM {{ ref('stg_raw__locations') }})
)

SELECT 
    user_contract_id,
    membership_id,
    location_id,
    account_id,
    contract_start,
    contract_end,
    contract_start_week,
    contract_end_week
FROM contracts_with_priority
WHERE rank_priority = 1

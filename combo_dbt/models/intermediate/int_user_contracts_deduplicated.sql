WITH base_contracts AS (
    SELECT 
        user_contract_id,
        membership_id,
        location_id,
        account_id,
        contract_start,
        -- Si la date de fin est nulle (CDI), on affecte une date lointaine pour le calcul de chevauchement
        COALESCE(contract_end, '2099-12-31'::date) AS contract_end_cleaned,
        contract_end,
        contract_type,
        -- Application de l'échelle métier de priorité
        CASE contract_type
            WHEN 'CDI' THEN 1
            WHEN 'apprentissage' THEN 2
            WHEN 'CDD' THEN 3
            WHEN 'seasonal' THEN 4
            ELSE 5
        END AS priority_score
    FROM {{ ref('stg_raw__user_contracts') }}
    INNER JOIN {{  ref('stg_raw__memberships') }} USING(membership_id)
    INNER JOIN {{  ref('stg_raw__locations') }} USING(location_id)
),

find_overlaps AS (
    SELECT 
        c1.user_contract_id,
        c1.membership_id,
        c1.location_id,
        c1.account_id,
        c1.contract_start,
        c1.contract_end,
        c1.contract_type,
        c1.priority_score,
        -- On cherche s'il existe UN AUTRE contrat pour le même salarié qui chevauche celui-ci
        -- ET qui possède un meilleur score de priorité (un chiffre plus bas)
        -- OU qui a le même score mais qui a démarré plus tôt / plus tard (pour départager)
        EXISTS (
            SELECT 1 
            FROM base_contracts c2
            WHERE c1.membership_id = c2.membership_id
              AND c1.user_contract_id <> c2.user_contract_id
              -- Condition de chevauchement de dates standard : (StartA <= EndB) ET (EndA >= StartB)
              AND c1.contract_start <= c2.contract_end_cleaned
              AND c1.contract_end_cleaned >= c2.contract_start
              -- Condition de dépriorisation : c2 est plus prioritaire que c1
              AND (
                  c2.priority_score < c1.priority_score
                  OR (c2.priority_score = c1.priority_score AND c2.contract_start > c1.contract_start)
                  OR (c2.priority_score = c1.priority_score AND c2.contract_start = c1.contract_start AND c2.user_contract_id < c1.user_contract_id)
              )
        ) AS should_be_excluded
    FROM base_contracts c1
)

SELECT 
    user_contract_id,
    membership_id,
    location_id,
    account_id,
    contract_start,
    contract_end,
    contract_type,
    DATE_TRUNC('week', contract_start) AS contract_start_week,
    DATE_TRUNC('week', contract_end) AS contract_end_week
FROM find_overlaps
WHERE NOT should_be_excluded
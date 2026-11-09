{{ config(materialized='table') }}

WITH shifts AS (
    SELECT 
        CONCAT('shift_', shift_id) AS event_id,
        user_contract_id,
        DATE_TRUNC('week', shift_start_date) AS event_week,
        shift_start_date AS start_date,
        shift_end_date AS end_date,
        account_id
    FROM {{ ref('stg_raw__shifts') }}
    WHERE datediff(hour, shift_start_date, shift_end_date) <= 24
),

rests AS (
    SELECT 
        CONCAT('rest_', rest_id) AS event_id,
        user_contract_id,
        DATE_TRUNC('week', rest_start_date) AS event_week,
        rest_start_date AS start_date,
        rest_end_date AS end_date,
        account_id
    FROM {{ ref('stg_raw__rests') }} r
    INNER JOIN {{ ref('dim_calendars') }} cal
        ON cal.date_actual >= CAST(r.rest_start_date AS DATE)
       AND cal.date_actual <= CAST(r.rest_end_date AS DATE)
),

all_events AS (
    SELECT * FROM shifts
    UNION ALL
    SELECT * FROM rests
),

-- Appel du modèle de contrat nettoyé en amont
cleaned_contracts AS (
    SELECT * FROM {{ ref('int_user_contracts_deduplicated') }}
),

-- C'est ici qu'on élimine les événements hors contrat
filtered_events AS (
    SELECT 
        ev.user_contract_id,
        ev.event_week,
        -- S'il n'y a pas de contrat, on récupère l'account_id directement depuis le shift/rest pour pouvoir facturer la bonne entreprise
        COALESCE(c.account_id, ev.account_id) AS account_id,
        c.location_id,
        c.membership_id
    FROM all_events ev
    INNER JOIN cleaned_contracts c 
        ON ev.user_contract_id = c.user_contract_id -- Un shift ou un repos doit être associé à un contrat et donc un utilisateur connu
    WHERE 
        (c.user_contract_id IS NOT NULL 
         AND ev.start_date >= c.contract_start
         AND (c.contract_end IS NULL OR ev.end_date <= c.contract_end))
)

-- Agrégation finale
SELECT DISTINCT
    membership_id,
    event_week,
    account_id,
    location_id,
    user_contract_id
FROM filtered_events

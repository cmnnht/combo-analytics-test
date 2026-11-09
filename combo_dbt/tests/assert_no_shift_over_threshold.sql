{{ config(
    severity='warn',
    store_failures=true
) }}

-- Ce test échoue si un shift a une durée strictement supérieure à 48 heures.
-- Dans le modèle RH de Combo, un tel écart est synonyme d'une erreur de saisie.
WITH shift_durations AS (
    select
        shift_id,
        user_contract_id,
        account_id,
        shift_start_date,
        shift_end_date,
        -- Calcul de la différence en heures entre le début et la fin du shift
        {{ dbt.datediff("shift_start_date", "shift_end_date", "hour") }} AS duration_hours
    from {{ ref('stg_raw__shifts') }}
)

SELECT
    shift_id,
    user_contract_id,
    account_id,
    shift_start_date,
    shift_end_date,
    duration_hours
FROM shift_durations
WHERE duration_hours > {{ var('max_shift_duration_hours', 48) }}
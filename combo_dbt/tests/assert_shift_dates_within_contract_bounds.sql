{{ config(
    severity='warn',
    store_failures=true
) }}

-- Ce test échoue si un shift commence avant le début du contrat 
-- ou se termine après la fin du contrat (lorsque le contrat a une date de fin).
WITH shift_and_contract_dates AS (
    SELECT
        s.shift_id AS shift_id,
        s.user_contract_id,
        -- On convertit les timestamps des shifts en dates pour comparer avec le contrat
        CAST(s.shift_start_date AS DATE) AS shift_start_date,
        CAST(s.shift_end_date AS DATE) AS shift_end_date,
        c.contract_start,
        -- Si contract_end est null (CDI), on applique une date infinie
        COALESCE(c.contract_end, CAST('2050-01-01' AS DATE)) AS contract_end
    FROM {{ ref('stg_raw__shifts') }} s
    INNER JOIN {{ ref('stg_raw__user_contracts') }} c
        ON s.user_contract_id = c.user_contract_id
)

SELECT
    shift_id,
    user_contract_id,
    shift_start_date,
    shift_end_date,
    contract_start,
    contract_end
FROM shift_and_contract_dates
-- L'anomalie est détectée si le shift sort des barrières du contrat
WHERE shift_start_date < contract_start
   OR shift_end_date > contract_end

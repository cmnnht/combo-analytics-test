WITH employee_counts_per_week AS (
    SELECT 
        account_id,
        location_id,
        event_week,
        COUNT(DISTINCT membership_id) AS active_employees_count_per_week
    FROM {{ ref('int_employee_weekly_events') }}
    GROUP BY 1, 2, 3
),

-- On ne sélectionne que les établissements facturables i.e non archivés
location_size_price AS (
    SELECT 
        ec.location_id,
        ec.account_id,
        ec.event_week,
        ec.active_employees_count_per_week,
        bl.location_size_tarification_id,
        bl.base_monthly_price AS base_price
    FROM employee_counts_per_week AS ec
    INNER JOIN {{ ref('int_billable_location') }} AS l
        USING(location_id)
    LEFT JOIN {{ ref('tarification_per_location_type') }} AS bl
       ON ec.active_employees_count_per_week BETWEEN bl.min_range AND bl.max_range
),

extra_employee_price AS (
    SELECT 
        lsp.location_id,
        lsp.account_id,
        lsp.event_week,
        lsp.active_employees_count_per_week,
        lsp.location_size_tarification_id,
        lsp.base_price,
        ext.extra_employee_tarification_id,
        -- Sécurité : On facture à partir du 7ème (actif - 6), uniquement si le compte atteint au moins 7
        CASE 
            WHEN lsp.active_employees_count_per_week >= 6 
            THEN ext.extra_monthly_price  * (lsp.active_employees_count_per_week - 6)
            ELSE 0 
        END AS extra_employee_price
    FROM location_size_price lsp
    LEFT JOIN {{ ref('tarification_per_extra_employee') }} AS ext
       ON lsp.active_employees_count_per_week BETWEEN ext.min_range AND ext.max_range
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['location_id', 'event_week']) }} AS location_weekly_metrics_pk,
    location_id,
    account_id,
    event_week AS aggregation_week,
    active_employees_count_per_week AS active_employees_count,
    location_size_tarification_id AS location_size,
    COALESCE(base_price, 0) AS base_price,
    extra_employee_price,
    (COALESCE(base_price, 0) + extra_employee_price) AS total_weekly_location_price
FROM extra_employee_price

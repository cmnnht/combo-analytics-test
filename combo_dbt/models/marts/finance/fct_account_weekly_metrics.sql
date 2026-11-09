WITH billing_per_location_per_week AS (
    SELECT  
        account_id,
        location_id,
        aggregation_week,
        active_employees_count,
        total_weekly_location_price
    FROM {{ ref('int_weekly_location_metrics') }}
),

weekly_billing_per_account AS (
    SELECT 
        account_id,
        aggregation_week,
        -- Nombre d'établissements facturables sur le compte
        COUNT(DISTINCT location_id) AS total_billable_locations_count,
        -- Nombre d'employés facturables cumulés sur le compte
        SUM(active_employees_count) AS total_billable_employees_count
    FROM billing_per_location_per_week
    GROUP BY 1, 2
)

SELECT 
    {{ dbt_utils.generate_surrogate_key(['account_id', 'aggregation_week']) }} AS account_weekly_metrics_pk,
    account_id, 
    CAST(TO_CHAR(aggregation_week, 'YYYYMMDD') AS INTEGER) AS date_key,
    aggregation_week  AS metrics_week_start_date,

    -- Métriques de volume
    total_billable_locations_count,
    total_billable_employees_count
FROM weekly_billing_per_account
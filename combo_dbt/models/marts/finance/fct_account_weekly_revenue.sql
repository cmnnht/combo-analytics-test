WITH billing_per_location_per_week AS(
    SELECT  
        account_id,
        location_id,
        aggregation_week,
        base_price,
        extra_employee_price,
        total_weekly_location_price
    FROM {{ ref('int_weekly_location_metrics')}}
),

weekly_revenue_per_account AS(
    SELECT 
        account_id,
        aggregation_week,
        -- Composantes intermédiaires
        SUM(base_price) AS total_base_revenue,
        SUM(extra_employee_price) AS   total_extra_employee_revenue,
        -- Revenu hebdomadaire par compte
        SUM(total_weekly_location_price) AS total_expected_weekly_revenue
    FROM billing_per_location_per_week
    GROUP BY 1, 2
)

SELECT 
    {{ dbt_utils.generate_surrogate_key(['account_id', 'aggregation_week']) }} as account_weekly_revenue_pk,
    account_id, 
    CAST(TO_CHAR(aggregation_week, 'YYYYMMDD') AS INTEGER) AS date_key,
    aggregation_week AS metrics_week_start_date,

    -- Métriques financières
    total_base_revenue,
    total_extra_employee_revenue,
    total_expected_weekly_revenue
FROM weekly_revenue_per_account

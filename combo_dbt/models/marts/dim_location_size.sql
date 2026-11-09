SELECT
    location_size_tarification_id,
    location_size_tarification_code
    location_size_tarification_label,
    base_monthly_price,
    min_range,
    -- Gestion de la borne infinie pour la tranche Grand (40+)
    COALESCE(max_range, NULL) AS max_range
FROM {{ ref('tarification_per_location_type') }}
SELECT
    location_id,
    location_name,
    city,
    zip_code,
    address
FROM {{ ref('stg_raw__locations') }}
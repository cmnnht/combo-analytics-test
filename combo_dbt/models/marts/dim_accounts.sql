SELECT
    account_id,
    account_name,
    country,
    time_zone
FROM {{ ref('stg_raw__accounts') }}
SELECT
    id                                 AS rest_id,
    user_contract_id                   AS user_contract_id,
    account_id,
    {{ clean_snowflake_utc_date('starts_at') }}         AS rest_start_date,
    {{ clean_snowflake_utc_date('ends_at') }}           AS rest_end_date,
    COALESCE(rest_type, 'unknown')     AS rest_type,
    timeoff_id,
    original_shift_id,
    {{ clean_snowflake_utc_date('created_at') }}         AS created_at,
    {{ clean_snowflake_utc_date('updated_at') }}         AS updated_at,
    partner_id,
    custom_value
FROM {{ source('raw', 'rests') }}


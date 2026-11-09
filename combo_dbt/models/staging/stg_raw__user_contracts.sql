SELECT
    id AS user_contract_id,
    {{ clean_snowflake_utc_date('created_at') }} AS created_at,
    {{ clean_snowflake_utc_date('updated_at') }} AS updated_at,
    location_id,
    CASE 
        WHEN TRIM(contract_end) LIKE '%/%' 
            THEN TRY_TO_DATE(TRIM(contract_end), 'DD/MM/YYYY')
        ELSE TRY_TO_DATE(TRIM(contract_end), 'YYYY-MM-DD')
    END AS contract_end,
    -- Nettoyage et conversion en FLOAT
    CASE 
        -- 1. Si la valeur contient 'h', on supprime le 'h' et on remplace la virgule par un point
        WHEN contract_time LIKE '%h%' 
            THEN TO_DOUBLE(replace(replace(contract_time, 'h', ''), ',', '.'))
        
        -- 2. Si la valeur contient une virgule, on la remplace simplement par un point
        WHEN contract_time LIKE '%,%' 
            THEN TO_DOUBLE(replace(contract_time, ',', '.'))
        
        -- 3. Pour les autres cas (déjà des chiffres ou points), on cast directement en double
        ELSE TRY_TO_DOUBLE(contract_time)
    END                            AS contract_time_hours,
    CASE 
        WHEN TRIM(contract_start) LIKE '%/%' 
            THEN TRY_TO_DATE(TRIM(contract_start), 'DD/MM/YYYY')
        ELSE TRY_TO_DATE(TRIM(contract_start), 'YYYY-MM-DD')
    END AS contract_start,
    TRY_TO_DATE(TRIM(contract_end_trial), 'YYYY-MM-DD') AS contract_end_trial,
    COALESCE(contract_type, 'unknown') AS contract_type,
    lastname                           AS last_name,
    firstname                          AS first_name,
    street_address,
    do_not_show_in_register,
    contract_end_reason,
    team_id,
    {{ clean_snowflake_utc_date('invitation_sent_at') }} AS invitation_sent_at,
    {{ clean_snowflake_utc_date('invitation_accepted_at') }} AS invitation_accepted_at,
    membership_id,
    daily_worker,
    working_days_in_week,
    partner_id,
    birth_department_code,
    start_time,
    account_id,
    original_contract_id,
    type,
    virtual 
FROM {{ source('raw', 'user_contracts') }}
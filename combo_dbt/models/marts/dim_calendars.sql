{{ config(
    materialized='table',
    description='Master calendar dimension table generated using dbt_utils.date_spine.'
) }}

with date_spine as (
    -- Generates a continuous daily sequence using project variables
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('calendar_start_date') ~ "' as date)",
        end_date="cast('" ~ var('calendar_end_date') ~ "' as date)"
    ) }}
),

calculated_dates as (
    select
        cast(date_day as date) as date_actual
    from date_spine
),

final as (
    select
        -- Primary Key: Smart surrogate key format YYYYMMDD
        cast(to_char(date_actual, 'YYYYMMDD') as integer) as date_key,
        date_actual,
        
        -- Year Attributes
        extract(year from date_actual) as year_actual,
        
        -- Quarter Attributes
        extract(quarter from date_actual) as quarter_actual,
        'Q' || extract(quarter from date_actual) as quarter_name,
        
        -- Month Attributes
        extract(month from date_actual) as month_actual,
        to_char(date_actual, 'Month') as month_name,
        to_char(date_actual, 'Mon') as month_name_short,
        
        -- Week Attributes
        extract(week from date_actual) as week_of_year,
        
        -- Day Attributes
        extract(day from date_actual) as day_of_month,
        extract(dow from date_actual) as day_of_week, -- 0 = Sunday or Monday depending on warehouse settings
        to_char(date_actual, 'Day') as day_name,
        
        -- Boolean Flags
        case when extract(dow from date_actual) in (0, 6) then true else false end as is_weekend
        
    from calculated_dates
)

select * from final

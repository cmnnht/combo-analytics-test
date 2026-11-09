{% macro clean_snowflake_utc_date(column_name) %}
    TRY_TO_TIMESTAMP_NTZ(REPLACE({{ column_name }}, ' UTC', ''))
{% endmacro %}
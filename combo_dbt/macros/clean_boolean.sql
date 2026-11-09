{% macro clean_boolean(column_name) %}
   CASE 
            WHEN LOWER({{  column_name  }}) IN ('true', 'yes', '1') THEN true
            WHEN LOWER({{  column_name  }}) IN ('false', 'no', '0') THEN false
            ELSE NULL -- Optionnel : gère les cas vides ou aberrants
        END
{% endmacro %}
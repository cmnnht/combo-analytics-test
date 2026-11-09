{{ config(materialized='ephemeral') }}
-- Exclusion de tous les établissements archivés ou non liés à un compte existant en base
SELECT DISTINCT
    l.location_id,
    l.location_name,
    l.account_id
FROM  {{ ref('stg_raw__locations') }} l
INNER JOIN {{ ref('stg_raw__accounts')}} a
  ON l.account_id = a.account_id
WHERE l.is_archived = FALSE
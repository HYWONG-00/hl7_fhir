{% macro create_masking_policy_mp_encrypt_pii(node_database, node_schema) %}
  CREATE MASKING POLICY IF NOT EXISTS {{node_database}}.{{node_schema}}.mp_encrypt_pii 
  AS (val STRING) RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() IN ('SYSADMIN') THEN val
      ELSE '***MASKED***'
    END
{% endmacro %}
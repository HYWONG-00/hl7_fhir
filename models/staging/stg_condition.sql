with raw_source as (
    select json_string from {{ source("fhir_sources", "PATIENT") }}
),

flattened_data as (
    select 
    JSON_STRING:entry[0].fullUrl::string PATIENT_ID,
    CONDITION_FLAT_SRC.value as condition_flat, 
    CODING_SRC.value as coding 
    from raw_source
        , LATERAL FLATTEN(INPUT => JSON_STRING:entry) CONDITION_FLAT_SRC
        , LATERAL FLATTEN(INPUT => CONDITION_FLAT_SRC.VALUE:resource.code.coding) CODING_SRC
        WHERE UPPER(CONDITION_FLAT_SRC.VALUE:request.url::string) = 'CONDITION'
)

-- select condition_flat, coding from flattened_data

SELECT
        condition_flat:fullUrl::string condition_id,
        coding:code::string CONDITION_CD,
        UPPER(coding:display::string) CONDITION_DESC,
        UPPER(condition_flat:resource.code.text::string) CONDITION_TXT,
        condition_flat:resource.assertedDate::date ASSERTED_DTTM,
        condition_flat:resource.onsetDateTime::date ONSET_DTTM,
        condition_flat:resource.abatementDateTime::date ABATEMENT_DTTM,
        UPPER(condition_flat:resource.verificationStatus::string) VERIFICATION_STATUS,
        UPPER(condition_flat:resource.clinicalStatus::string) CLINICAL_STATUS,
        1 CONDITION_CNT

FROM flattened_data
with raw_source as (
    -- Dynamically links to your validated source configuration
    select json_string 
    from {{ source('fhir_sources', 'PATIENT') }}
),

flattened_data as (
    select
        json_string:entry[0].fullUrl::string as patient_id,
        identifier.value as identifier_value,
        extension.value as extension_value,
        address.value as address_value,
        patient_flat.value as patient_flat_value
    from raw_source
    , lateral flatten(input => json_string:entry) patient_flat
    , lateral flatten(input => patient_flat.value:resource:identifier) identifier
    , lateral flatten(input => patient_flat.value:resource:extension) extension
    , lateral flatten(input => patient_flat.value:resource:address) address
    where upper(patient_flat.value:resource:resourceType::string) = 'PATIENT'
)

select
    patient_id,
    min(decode(identifier_value:type.text, 'Medical Record Number', identifier_value:value::string)) as patient_mrn,
    min(decode(identifier_value:type.text, 'Social Security Number', identifier_value:value::string)) as patient_ssn,
    min(decode(identifier_value:type.text, 'Driver\'s License', identifier_value:value::string)) as patient_drivers_license_num,
    min(decode(identifier_value:type.text, 'Passport Number', identifier_value:value::string)) as patient_passport_num,
    upper(any_value(upper(patient_flat_value:resource:name[0].family::string))) as patient_last_nm,
    upper(any_value(upper(patient_flat_value:resource:name[0].given[0]::string))) as patient_first_nm,
    upper(any_value(upper(patient_flat_value:resource:name[0].prefix[0]::string))) as patient_nm_prefix,
    any_value(upper(patient_flat_value:resource:gender::string)) as patient_sex,
    upper(decode(min(decode(extension_value:url, 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex', extension_value:valueCode::string)), 'M', 'Male', 'F', 'Female', 'Unknown')) as patient_birth_sex,
    upper(min(decode(extension_value:url, 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race', extension_value:extension[0]:valueCoding.display::string))) as patient_core_race,
    upper(min(decode(extension_value:url, 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity', extension_value:extension[0]:valueCoding.display::string))) as patient_core_ethnicity,
    upper(decode(any_value(patient_flat_value:resource:maritalStatus.text::string), 'M', 'Married', 'S', 'Single', any_value(patient_flat_value:resource:maritalStatus.text::string))) as patient_marital_status,
    trunc(any_value(patient_flat_value:resource:birthDate::date), 'D') as patient_birth_dt,
    upper(coalesce(any_value(patient_flat_value:resource:multipleBirthBoolean::string), 'Unknown')) as patient_multiple_birth_ind,
    upper(min(decode(extension_value:url, 'http://hl7.org/fhir/StructureDefinition/birthPlace', extension_value:valueAddress:city::string))) as patient_birth_city,
    upper(min(decode(extension_value:url, 'http://hl7.org/fhir/StructureDefinition/birthPlace', extension_value:valueAddress:country::string))) as patient_birth_country,
    upper(min(decode(extension_value:url, 'http://hl7.org/fhir/StructureDefinition/birthPlace', extension_value:valueAddress:state::string))) as patient_birth_state,
    trunc(any_value(patient_flat_value:resource:deceasedDateTime::date), 'D') as patient_death_dt,
    upper(any_value(decode(patient_flat_value:resource:deceasedDateTime::date, null, 'Unknown', 'true'))) as patient_deceased_ind,
    upper(min(decode(extension_value:url, 'http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName', extension_value:valueString::string))) as patient_mothers_maiden_name,
    upper(any_value(address_value:line[0]::string)) as patient_addr_line1,
    upper(any_value(address_value:line[1]::string)) as patient_addr_line2,
    upper(any_value(address_value:line[2]::string)) as patient_addr_line3,
    upper(any_value(address_value:city::string)) as patient_city,
    upper(any_value(address_value:state::string)) as patient_state,
    upper(any_value(address_value:country::string)) as patient_country,
    any_value(address_value:postalCode::string) as patient_postal_cd,
    any_value(coalesce(decode(address_value:extension[0]:extension[0].url::string, 'latitude', address_value:extension[0]:extension[0].valueDecimal::float), decode(address_value:extension[0]:extension[1].url::string, 'latitude', address_value:extension[0]:extension[1].valueDecimal::float))) as patient_latitude,
    any_value(coalesce(decode(address_value:extension[0]:extension[0].url::string, 'longitude', address_value:extension[0]:extension[0].valueDecimal::float), decode(address_value:extension[0]:extension[1].url::string, 'longitude', address_value:extension[0]:extension[1].valueDecimal::float))) as patient_longitude,
    min(decode(extension_value:url, 'http://synthetichealth.github.io/synthea/disability-adjusted-life-years', extension_value:valueDecimal::string)) as patient_disability_adjusted_life_years,
    min(decode(extension_value:url, 'http://synthetichealth.github.io/synthea/quality-adjusted-life-years', extension_value:valueDecimal::string)) as patient_quality_adjusted_life_years,
    1 as patient_cnt
from flattened_data
group by patient_id
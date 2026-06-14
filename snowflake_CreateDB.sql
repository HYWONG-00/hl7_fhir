USE ROLE SYSADMIN;

CREATE OR REPLACE DATABASE HL7_FHIR COMMENT = "HL7 FHIR DATABASE";
CREATE OR REPLACE SCHEMA HL7_FHIR_V1;

-- Create a compute warehouse that will be the main compute resource to load files into snowflake
CREATE OR REPLACE WAREHOUSE "HL7_FHIR_WH"
    WAREHOUSE_SIZE = 'SMALL'
    INITIALLY_SUSPENDED = FALSE
    AUTO_SUSPEND=600
    AUTO_RESUME=TRUE
    MIN_CLUSTER_COUNT=1
    MAX_CLUSTER_COUNT=1
    SCALING_POLICY='STANDARD'
    COMMENT='';

USE SCHEMA HL7_FHIR_V1;
-- a place to store data
CREATE OR REPLACE STAGE HL7_FHIR_STAGE_INTERNAL
DIRECTORY = (ENABLE = TRUE)
COMMENT = "Used For Staging Data";

-- If it is external stage,
-- CREATE OR REPLACE STAGE HL7_FHIR_STAGE_EXTERNAL
--   URL = 's3://my-bucket-name/hl7_data/'
--   STORAGE_INTEGRATION = my_s3_integration
--   DIRECTORY = ( ENABLE = TRUE )
--   COMMENT = 'Used For Staging Data Externally in S3';

-- Retrieving account identifier 
SELECT REPLACE(T.VALUE:host::VARCHAR, '.snowflakecomputing.com') AS ACCOUNT_IDENTIFIER
FROM TABLE(FLATTEN(INPUT => PARSE_JSON(system$allowlist()))) AS T
WHERE T.VALUE:type::VARCHAR = 'SNOWFLAKE_DEPLOYMENT_REGIONLESS';

-- Load sample HL7 FHIR data using snowsql in terminal in your local laptop

-- refresh the stage 
ALTER STAGE HL7_FHIR_STAGE_INTERNAL REFRESH; 
SELECT * FROM DIRECTORY(@HL7_FHIR_STAGE_INTERNAL);


-- Loading HL7 FHIR messages into Snowflake table
CREATE TABLE HL7_FHIR.HL7_FHIR_V1.PATIENT
(JSON_STRING VARIANT);
-- DROP TABLE HL7_FHIR.HL7_FHIR_V1.PATIENT;

-- tell snowflake how to read the structure of my incoming files
CREATE FILE FORMAT HL7_FHIR.HL7_FHIR_V1.JSON
TYPE='JSON'
-- will automatically uncompress them during upload process
COMPRESSION='AUTO'
-- treat any leading zeors as string
ENABLE_OCTAL=FALSE
ALLOW_DUPLICATE=FALSE
-- Sometimes, an entire JSON file is wrapped in an outer set of square brackets [ ... ] representing an array of multiple records.
-- FALSE = each file is a single complete JSON root object.
STRIP_OUTER_ARRAY=FALSE
STRIP_NULL_VALUES=FALSE
IGNORE_UTF8_ERRORS=FALSE;

SHOW FILE FORMATS IN DATABASE HL7_FHIR;

--  use COPY command to load data into patient tbale
COPY INTO HL7_FHIR.HL7_FHIR_V1.PATIENT 
FROM @HL7_FHIR_STAGE_INTERNAL
FILE_FORMAT = (FORMAT_NAME='JSON')
on_error = "SKIP_FILE";

-- select raw JSON
SELECT * FROM HL7_FHIR.HL7_FHIR_V1.PATIENT LIMIT 5;

--Create PATIENTS_VW view
-- CREATE OR REPLACE VIEW HL7_FHIR.HL7_FHIR_V1.PATIENTS_VW AS
--     SELECT
--         JSON_STRING:entry[0].fullUrl::string PATIENT_ID,
--         MIN(DECODE(IDENTIFIER.VALUE:type.text,'Medical Record Number',IDENTIFIER.VALUE:value::string)) PATIENT_MRN,
--         MIN(DECODE(IDENTIFIER.VALUE:type.text,'Social Security Number',IDENTIFIER.VALUE:value::string)) PATIENT_SSN,
--         MIN(DECODE(IDENTIFIER.VALUE:type.text,'Driver\'s License',IDENTIFIER.VALUE:value::string)) PATIENT_DRIVERS_LICENSE_NUM,
--         MIN(DECODE(IDENTIFIER.VALUE:type.text,'Passport Number',IDENTIFIER.VALUE:value::string)) PATIENT_PASSPORT_NUM,
--         UPPER(ANY_VALUE(UPPER(PATIENT_FLAT.VALUE:resource:name[0].family::string))) PATIENT_LAST_NM,
--         UPPER(ANY_VALUE(UPPER(PATIENT_FLAT.VALUE:resource:name[0].given[0]::string))) PATIENT_FIRST_NM,
--         UPPER(ANY_VALUE(UPPER(PATIENT_FLAT.VALUE:resource:name[0].prefix[0]::string))) PATIENT_NM_PREFIX,
--         ANY_VALUE(UPPER(PATIENT_FLAT.VALUE:resource:gender::string)) PATIENT_SEX,
--         UPPER(DECODE(MIN(DECODE(EXTENSION.VALUE:url,'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex',EXTENSION.VALUE:valueCode::string)),'M','Male',
--         'F','Female',
--         'Unknown')) PATIENT_BIRTH_SEX,
--         UPPER(MIN(DECODE(EXTENSION.VALUE:url,'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race',EXTENSION.VALUE:extension[0]:valueCoding.display::string))) PATIENT_CORE_RACE,
--         UPPER(MIN(DECODE(EXTENSION.VALUE:url,'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity',EXTENSION.VALUE:extension[0]:valueCoding.display::string))) PATIENT_CORE_ETHNICITY,
--         UPPER(DECODE(ANY_VALUE(PATIENT_FLAT.VALUE:resource:maritalStatus.text::string),'M','Married',
--         'S','Single',
--         ANY_VALUE(PATIENT_FLAT.VALUE:resource:maritalStatus.text::string))) PATIENT_MARITAL_STATUS,
--         TRUNC(ANY_VALUE(PATIENT_FLAT.VALUE:resource:birthDate::date),'D') PATIENT_BIRTH_DT,
--         UPPER(COALESCE(ANY_VALUE(PATIENT_FLAT.VALUE:resource:multipleBirthBoolean::string),'Unknown')) PATIENT_MULTIPLE_BIRTH_IND,
--         UPPER(MIN(DECODE(EXTENSION.VALUE:url,'http://hl7.org/fhir/StructureDefinition/birthPlace',EXTENSION.VALUE:valueAddress:city::string))) PATIENT_BIRTH_CITY,
--         UPPER(MIN(DECODE(EXTENSION.VALUE:url,'http://hl7.org/fhir/StructureDefinition/birthPlace',EXTENSION.VALUE:valueAddress:country::string))) PATIENT_BIRTH_COUNTRY,
--         UPPER(MIN(DECODE(EXTENSION.VALUE:url,'http://hl7.org/fhir/StructureDefinition/birthPlace',EXTENSION.VALUE:valueAddress:state::string))) PATIENT_BIRTH_STATE,
--         TRUNC(ANY_VALUE(PATIENT_FLAT.VALUE:resource:deceasedDateTime::date),'D') PATIENT_DEATH_DT,
--         UPPER(ANY_VALUE(DECODE(PATIENT_FLAT.VALUE:resource:deceasedDateTime::date,NULL,'Unknown','true'))) PATIENT_DECEASED_IND,
--         UPPER(MIN(DECODE(EXTENSION.VALUE:url,'http://hl7.org/fhir/StructureDefinition/patient-mothersMaidenName',EXTENSION.VALUE:valueString::string))) PATIENT_MOTHERS_MAIDEN_NAME,
--         UPPER(ANY_VALUE(ADDRESS.VALUE:line[0]::string)) PATIENT_ADDR_LINE1,
--         UPPER(ANY_VALUE(ADDRESS.VALUE:line[1]::string)) PATIENT_ADDR_LINE2,
--         UPPER(ANY_VALUE(ADDRESS.VALUE:line[2]::string)) PATIENT_ADDR_LINE3,
--         UPPER(ANY_VALUE(ADDRESS.VALUE:city::string)) PATIENT_CITY,
--         UPPER(ANY_VALUE(ADDRESS.VALUE:state::string)) PATIENT_STATE,
--         UPPER(ANY_VALUE(ADDRESS.VALUE:country::string)) PATIENT_COUNTRY,
--         ANY_VALUE(ADDRESS.VALUE:postalCode::string) PATIENT_POSTAL_CD,
--         ANY_VALUE(COALESCE(DECODE(ADDRESS.VALUE:extension[0]:extension[0].url::string,'latitude',ADDRESS.VALUE:extension[0]:extension[0].valueDecimal::float),DECODE(ADDRESS.VALUE:extension[0]:extension[1].url::string,'latitude',ADDRESS.VALUE:extension[0]:extension[1].valueDecimal::float))) PATIENT_LATITUDE,
--         ANY_VALUE(COALESCE(DECODE(ADDRESS.VALUE:extension[0]:extension[0].url::string,'longitude',ADDRESS.VALUE:extension[0]:extension[0].valueDecimal::float),DECODE(ADDRESS.VALUE:extension[0]:extension[1].url::string,'longitude',ADDRESS.VALUE:extension[0]:extension[1].valueDecimal::float))) PATIENT_LONGITUDE,
--         MIN(DECODE(EXTENSION.VALUE:url,'http://synthetichealth.github.io/synthea/disability-adjusted-life-years',EXTENSION.VALUE:valueDecimal::string)) PATIENT_DISABILITY_ADJUSTED_LIFE_YEARS,
--         MIN(DECODE(EXTENSION.VALUE:url,'http://synthetichealth.github.io/synthea/quality-adjusted-life-years',EXTENSION.VALUE:valueDecimal::string)) PATIENT_QUALITY_ADJUSTED_LIFE_YEARS,
--         1 PATIENT_CNT
--          FROM hl7_fhir.hl7_fhir_v1.PATIENT
--         , LATERAL FLATTEN(INPUT => JSON_STRING:entry) PATIENT_FLAT
--         , LATERAL FLATTEN(INPUT => PATIENT_FLAT.VALUE:resource:identifier) IDENTIFIER
--         , LATERAL FLATTEN(INPUT => PATIENT_FLAT.VALUE:resource:extension) EXTENSION
--         , LATERAL FLATTEN(INPUT => PATIENT_FLAT.VALUE:resource:address) ADDRESS
--     WHERE UPPER(PATIENT_FLAT.VALUE:resource:resourceType::string) = 'PATIENT'
--     GROUP BY
--     PATIENT_ID;



--Create CONDITIONS_VW view
 -- CREATE OR REPLACE VIEW HL7_FHIR.HL7_FHIR_V1.CONDITIONS_VW AS
 --    SELECT
 --        CONDITION_FLAT.value:fullUrl::string condition_id,
 --        JSON_STRING:entry[0].fullUrl::string PATIENT_ID,
 --        CODING.VALUE:code::string CONDITION_CD,
 --        UPPER(CODING.VALUE:display::string) CONDITION_DESC,
 --        UPPER(CONDITION_FLAT.VALUE:resource.code.text::string) CONDITION_TXT,
 --        CONDITION_FLAT.VALUE:resource.assertedDate::date ASSERTED_DTTM,
 --        CONDITION_FLAT.VALUE:resource.onsetDateTime::date ONSET_DTTM,
 --        CONDITION_FLAT.VALUE:resource.abatementDateTime::date ABATEMENT_DTTM,
 --        UPPER(CONDITION_FLAT.VALUE:resource.verificationStatus::string) VERIFICATION_STATUS,
 --        UPPER(CONDITION_FLAT.VALUE:resource.clinicalStatus::string) CLINICAL_STATUS,
 --        1 CONDITION_CNT
 --    FROM HL7_FHIR.HL7_FHIR_V1.PATIENT
 --        , LATERAL FLATTEN(INPUT => JSON_STRING:entry) CONDITION_FLAT
 --        , LATERAL FLATTEN(INPUT => CONDITION_FLAT.VALUE:resource.code.coding) CODING
 --    WHERE UPPER(CONDITION_FLAT.VALUE:request.url::string) = 'CONDITION';


-- Show HL7 FHIR data 
SELECT * FROM HL7_FHIR.HL7_FHIR_V1.PATIENTS_VW LIMIT 5;


---------------------------------------------------
-- Use Masking Policies to Protect Confidential data 
-- (Dynamic Data Masking to protect PII or HIPPA data by selecting different roles)
-- Create masking policy for PII
CREATE OR REPLACE MASKING POLICY SIMPLE_MASK_PII_CHAR AS
    (VAl CHAR) RETURNS CHAR ->
    CASE
    WHEN CURRENT_ROLE() IN ('SYSADMIN') THEN VAL
    ELSE '***PII MASKED***'
    END;

CREATE OR REPLACE MASKING POLICY SIMPLE_MASK_HIPAA_CHAR AS
(VAL CHAR) RETURNS CHAR ->
    CASE
    WHEN CURRENT_ROLE() IN ('SYSADMIN') THEN VAL
    ELSE '***PII MASKED***'
    END;

USE ROLE public;
select * from HL7_FHIR.DBT_HL7_FHIR.STG_PATIENTS LIMIT 5;
DESCRIBE VIEW HL7_FHIR.DBT_HL7_FHIR.STG_PATIENTS;
SHOW MASKING POLICIES;
-- https://www.snowflake.com/en/developers/guides/processing-hl7-fhir-messages-with-snowflake/

-- Now, applied these policies to specific columns in our view to protect our data. Apply PII policy to our patient ssn, HIPPA policy to birth_sex and patient birth city
ALTER VIEW HL7_FHIR.DBT_HL7_FHIR.STG_PATIENTS MODIFY COLUMN PATIENT_SSN SET MASKING POLICY SIMPLE_MASK_PII_CHAR;
ALTER VIEW HL7_FHIR.DBT_HL7_FHIR.STG_PATIENTS MODIFY COLUMN PATIENT_BIRTH_SEX SET MASKING POLICY SIMPLE_MASK_HIPAA_CHAR;
ALTER VIEW HL7_FHIR.DBT_HL7_FHIR.STG_PATIENTS MODIFY COLUMN PATIENT_BIRTH_CITY SET MASKING POLICY SIMPLE_MASK_HIPAA_CHAR;

-- TEST if our masking policy works
USE ROLE SYSADMIN;
USE ROLE ACCOUNTADMIN;
SELECT PATIENT_ID, PATIENT_MRN, PATIENT_SSN, PATIENT_DRIVERS_LICENSE_NUM, PATIENT_BIRTH_SEX, PATIENT_BIRTH_CITY FROM HL7_FHIR.DBT_HL7_FHIR.STG_PATIENTS
LIMIT 5;

-- Analyze FHIR messages using Snowsight
--Patients by Condition by Gender
SELECT PATIENTS_VW.PATIENT_SEX, CONDITIONS_VW.CONDITION_DESC, COUNT(*) AS PATIENT_COUNT
FROM PATIENTS_VW
JOIN CONDITIONS_VW ON PATIENTS_VW.PATIENT_ID=CONDITIONS_VW.PATIENT_ID
GROUP BY PATIENT_SEX, CONDITION_DESC
ORDER BY PATIENT_COUNT DESC;

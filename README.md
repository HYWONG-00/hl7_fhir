# Setup data pipeline from Snowflake - DBT - Microsoft Fabric (PowerBI)

This module is to setup the entire data pipeline based on medallion architecture (Bronze Layer in Snowflake, Silver Layer in DBT, Gold Layer semantic models stored in Snowflake and displayed in PowerBI). Taking HL7 FHIR dataset as example, I will load lists of the json file where each json records their personal details including their conditions in the hospital. This repository outlines the core steps required to ingest, store, process, and analyze healthcare HL7 FHIR JSON messages natively within Snowflake, DBT and PowerBI.

This is the architecture of the whole pipeline:

<img width="629" height="400" alt="HL7_FHIR drawio" src="https://github.com/user-attachments/assets/988ed206-7af7-4268-8569-c59ffaf7c83d" />

### Prepare data in Snowflake and load into Internal Stage (Bronze Layer)
First, install all the json files into local computer, https://synthetichealth.github.io/synthea-sample-data/downloads/synthea_sample_data_fhir_stu3_nov2021.zip.
**Please refer to snowflake_CreateDB.sql for all the code in Snowflake**
1. Prepare the Lab Environment by setting up the database, schema, and compute resources in Snowflake.
CREATE OR REPLACE DATABASE, CREATE OR REPLACE WAREHOUSE,.... that's how we do that in Snowflake
2. Then, setting up internal storage which is to temporarily hold your raw FHIR JSON files.

USE SCHEMA HL7_FHIR_V1;
CREATE OR REPLACE STAGE HL7_FHIR_STAGE_INTERNAL
   DIRECTORY = ( ENABLE = TRUE )
   COMMENT = 'Used For Staging Data'; 
   
5. Installed SnowSQL in local computer. Once you finish installed, open the terminal and run:
  snowsql -a <account-identifier> -u <username>
  Then, run these set of codes to upload all the RAW json files onto snowflake. It is important to specify where you want to save these json files in specific (eg.which database, which warehouse and which schema) :

  USE DATABASE HL7_FHIR;
  USE SCHEMA HL7_FHIR_V1;
  USE WAREHOUSE HL7_FHIR_WH;
  PUT 'file:////<path_to_your_json_files>/*.json' @HL7_FHIR_STAGE_INTERNAL;

7. You will need to tell snowflake how to read the structure of the incoming json files, eg. treat any leading zeros as string (ENABLE_OCTAL=FALSE), whether each file should be a single complete JSON root object / array of multiple records. All these settings is in CREATE FILE FORMAT ..... TYPE="JSON"
6.Then you can use COPY INYO command to load the data into patient table in internal stage, and this is how we setup the BRONZE LAYER!

SELECT * FROM HL7_FHIR.HL7_FHIR_V1.PATIENT LIMIT 5;

### Parse HL7 Json data in DBT
Very good. Now, let's transform the data to make it ready for PowerBI
setup the **dbt_projects.yml**, 
**src_sources.yml**: This file points dbt to your raw Snowflake landing tables so you don't have to hardcode database and schema names in your SQL queries.
Staging models:
Instead of one view, I break the nested FHIR JSON array into two staging files: one for Patients and one for Conditions.
**stg_patients.sql, stg_patients.yml**: This model flattens the JSON to isolate the PATIENT resource type.
**stg_condition.sql**:This model flattens the exact same JSON dataset but filters for the CONDITION resource type and maps it back to the patient_id (via the subject.reference JSON element).

Once these file are setup, run "dbt run --models stg_condition" and "dbt run --models stg_patients" respectively to load the tables into Snowflake! You can always go to Snowflake and check if the tables and views are successfully loaded.
<img width="1557" height="656" alt="image" src="https://github.com/user-attachments/assets/3d0345ef-83e8-4412-8ed5-61dd5c88bdf5" />

**ALWAYS REMEMBER TO dbt compile and make sure everything is right, then click Commit and sync to push the changes to Github repo**

### Setup masking policy in Snowflake
7. Setup masking policy to mask all the PII and HIPAA data, eg. patient's ssn, their birth sex and birth date, and ensure unless the person are with sysadmin role, otherwise it won't see these PII / HIPAA data
   eg. CREATE OR REPLACE MASKING POLICY SIMPLE_MASK_PII_CHAR AS
    (VAl CHAR) RETURNS CHAR ->
    CASE
    WHEN CURRENT_ROLE() IN ('SYSADMIN') THEN VAL
    ELSE '***PII MASKED***'
    END;
   ALTER VIEW HL7_FHIR.DBT_HL7_FHIR.STG_PATIENTS MODIFY COLUMN PATIENT_SSN SET MASKING POLICY SIMPLE_MASK_PII_CHAR;

Yeahh, transformation layer is DONE! Now, I just need to load semantic models into PowerBI!

### Loading Snowflake data into PowerBI 
Went to Microsoft Fabric and click Create > Get Data > search "Snowflake" and enter all the credentials, to link the tables. With that, semantic models are setup.
<img width="1437" height="815" alt="load in powerbi" src="https://github.com/user-attachments/assets/63838012-64a3-46b6-a0e9-335ec4fbf787" />
Now, open the semantic model itself, and setup the relationship to link based on Patient ID within "Manage the relationship" > "STG_CONDITION:PATIENT_ID    ---- One to Many (Both) ---- STG_PATIENTS:PATIENT_ID". Once finish, just proceed to the report and setup all the tables.

### Final Results
TA DA..., this is what we have on the PowerBI now. It visualize what is the most common condition for patient itself, by their cities.
<img width="1847" height="887" alt="image" src="https://github.com/user-attachments/assets/e711af29-8665-4b4a-b66d-15f633b7fabf" />


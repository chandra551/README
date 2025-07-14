
/* Import raw data from Excel */
PROC IMPORT OUT= WORK.RAW_DM
            DATAFILE= "C:\path\to\raw_dm_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;
DATA WORK.SDTM_DM;
    SET WORK.RAW_DM;

    /* Identifier Variables */
    LENGTH STUDYID DOMAIN USUBJID SUBJID $50;

    STUDYID = "HTN001";
    DOMAIN = "DM";
    USUBJID = CATX("-", STUDYID, SITEID, SUBJID);
    SUBJID = SUBJID;

    /* Topic & Record Qualifier Variables */
    RFSTDTC = RFXSTDTC; /* As per spec, same as first treatment date */
    RFXSTDTC = RFSTDTC;
    
    /* RFENDTC logic not available in this dataset - set missing */
    RFENDTC = .;
    RFXENDTC = RFENDTC;

    /* RFPENDTC (End of Participation) - Not available in raw data */
    RFPENDTC = .;

    /* Death Flag */
    IF DTHDTC NE . THEN DTHFL = "Y"; ELSE DTHFL = "N";

    /* Site Info */
    SITEID = SITEID;
    BRTHDTC = BRTHDTC;
    AGE = AGE;
    AGEU = "YEARS"; /* Default value */

    /* Sex Mapping */
    IF SEX = "Male" THEN SEX = "M";
    ELSE IF SEX = "Female" THEN SEX = "F";
    ELSE SEX = "U";

    /* Race Mapping */
    IF RACE = "ASIAN" THEN RACE = "ASIAN";
    ELSE IF RACE = "WHITE" THEN RACE = "WHITE";
    ELSE IF RACE = "BLACK OR AFRICAN AMERICAN" THEN RACE = "BLACK";
    ELSE IF RACE = "OTHER" THEN RACE = "OTHER";
    ELSE RACE = "UNK";

    /* Ethnicity Mapping */
    IF ETHNIC = "NOT HISPANIC OR LATINO" THEN ETHNIC = "NOT HISPANIC OR LATINO";
    ELSE IF ETHNIC = "HISPANIC OR LATINO" THEN ETHNIC = "HISPANIC OR LATINO";
    ELSE ETHNIC = "UNK";

    /* ARMCD Logic */
    IF RFSTDTC NE . THEN ARMCD = "A01-A02-A03";
    ELSE IF ARMCD = "" THEN ARMCD = "NOTASSGN";

    /* ARM Description */
    IF ARMCD = "A01-A02-A03" THEN ARM = "Placebo Controlled Trial";
    ELSE IF ARMCD = "NOTASSGN" THEN ARM = "Not Assigned";
    ELSE ARM = "UNKNOWN";

    ACTARMCD = ARMCD;
    ACTARM = ARM;

    /* Country Mapping (from DM_DETAILS tab logic if needed) */
    COUNTRY = "IND";

    /* Timing Variables */
    DMDTC = DMDTC;

    /* Supplemental/Other Variables */
    CENTRE = SITEID;
    PART = ""; /* Not available */
    RACEOTH = ""; /* Not provided in raw data */

    /* Keep only relevant variables */
    KEEP STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFXSTDTC RFENDTC RFXENDTC
         RFPENDTC DTHDTC DTHFL SITEID BRTHDTC AGE AGEU SEX RACE ETHNIC
         ARMCD ARM ACTARMCD ACTARM COUNTRY CENTRE PART RACEOTH DMDTC;
RUN;

DATA WORK.SDTM_DM;
    SET WORK.RAW_DM;

    /* Identifier Variables */
    LENGTH STUDYID DOMAIN USUBJID SUBJID $50;

    STUDYID = "HTN001";
    DOMAIN = "DM";
    USUBJID = CATX("-", STUDYID, SITEID, SUBJID);
    SUBJID = SUBJID;

    /* Topic & Record Qualifier Variables */
    RFSTDTC = RFXSTDTC; /* As per spec, same as first treatment date */
    RFXSTDTC = RFSTDTC;
    
    /* RFENDTC logic not available in this dataset - set missing */
    RFENDTC = .;
    RFXENDTC = RFENDTC;

    /* RFPENDTC (End of Participation) - Not available in raw data */
    RFPENDTC = .;

    /* Death Flag */
    IF DTHDTC NE . THEN DTHFL = "Y"; ELSE DTHFL = "N";

    /* Site Info */
    SITEID = SITEID;
    BRTHDTC = BRTHDTC;
    AGE = AGE;
    AGEU = "YEARS"; /* Default value */

    /* Sex Mapping */
    IF SEX = "Male" THEN SEX = "M";
    ELSE IF SEX = "Female" THEN SEX = "F";
    ELSE SEX = "U";

    /* Race Mapping */
    IF RACE = "ASIAN" THEN RACE = "ASIAN";
    ELSE IF RACE = "WHITE" THEN RACE = "WHITE";
    ELSE IF RACE = "BLACK OR AFRICAN AMERICAN" THEN RACE = "BLACK";
    ELSE IF RACE = "OTHER" THEN RACE = "OTHER";
    ELSE RACE = "UNK";

    /* Ethnicity Mapping */
    IF ETHNIC = "NOT HISPANIC OR LATINO" THEN ETHNIC = "NOT HISPANIC OR LATINO";
    ELSE IF ETHNIC = "HISPANIC OR LATINO" THEN ETHNIC = "HISPANIC OR LATINO";
    ELSE ETHNIC = "UNK";

    /* ARMCD Logic */
    IF RFSTDTC NE . THEN ARMCD = "A01-A02-A03";
    ELSE IF ARMCD = "" THEN ARMCD = "NOTASSGN";

    /* ARM Description */
    IF ARMCD = "A01-A02-A03" THEN ARM = "Placebo Controlled Trial";
    ELSE IF ARMCD = "NOTASSGN" THEN ARM = "Not Assigned";
    ELSE ARM = "UNKNOWN";

    ACTARMCD = ARMCD;
    ACTARM = ARM;

    /* Country Mapping (from DM_DETAILS tab logic if needed) */
    COUNTRY = "IND";

    /* Timing Variables */
    DMDTC = DMDTC;

    /* Supplemental/Other Variables */
    CENTRE = SITEID;
    PART = ""; /* Not available */
    RACEOTH = ""; /* Not provided in raw data */

    /* Keep only relevant variables */
    KEEP STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFXSTDTC RFENDTC RFXENDTC
         RFPENDTC DTHDTC DTHFL SITEID BRTHDTC AGE AGEU SEX RACE ETHNIC
         ARMCD ARM ACTARMCD ACTARM COUNTRY CENTRE PART RACEOTH DMDTC;
RUN;
PROC DATASETS LIBRARY=WORK;
    MODIFY SDTM_DM;
    LABEL
        STUDYID = 'Study Identifier'
        DOMAIN = 'Domain Abbreviation'
        USUBJID = 'Unique Subject Identifier'
        SUBJID = 'Subject Identifier for the Study'
        RFSTDTC = 'Subject Reference Start Date/Time'
        RFXSTDTC = 'Date/Time of First Study Treatment'
        RFENDTC = 'Subject Reference End Date/Time'
        RFXENDTC = 'Date/Time of Last Study Treatment'
        RFPENDTC = 'Date/Time of End of Participation'
        DTHDTC = 'Date/Time of Death'
        DTHFL = 'Subject Death Flag'
        SITEID = 'Study Site Identifier'
        BRTHDTC = 'Date/Time of Birth'
        AGE = 'Age'
        AGEU = 'Age Units'
        SEX = 'Sex'
        RACE = 'Race'
        ETHNIC = 'Ethnicity'
        ARMCD = 'Planned Arm Code'
        ARM = 'Description of Planned Arm'
        ACTARMCD = 'Actual Arm Code'
        ACTARM = 'Description of Actual Arm'
        COUNTRY = 'Country'
        CENTRE = 'Centre Number'
        PART = 'Study Part Code'
        RACEOTH = 'Other Race Specification'
        DMDTC = 'Date/Time of Collection';
RUN;
/* ------------------------ */
/* Step 1: Import DM & AE  */
/* ------------------------ */
PROC IMPORT OUT= WORK.SDTM_DM
            DATAFILE= "C:\path\to\raw_dm_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;

PROC IMPORT OUT= WORK.SDTM_AE
            DATAFILE= "C:\path\to\raw_ae_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;

/* --------------------------------- */
/* Step 2: Simulate SDTM_EX Dataset */
/* --------------------------------- */
DATA WORK.SDTM_EX;
    SET WORK.SDTM_DM (KEEP=USUBJID RFSTDTC);

    /* Simulate random treatment */
    IF MOD(_N_, 2) = 0 THEN EXTRT = "Drug";
    ELSE EXTRT = "Placebo";

    EXSTDTC = INPUT(RFSTDTC, ANYDTDTM.);

    /* 28-day treatment window */
    IF NOT MISSING(EXSTDTC) THEN EXENDTC = EXSTDTC + 28*86400;
    ELSE EXENDTC = .;

    FORMAT EXSTDTC EXENDTC DATETIME20.;
RUN;

/* -------------------------- */
/* Step 3: Merge DM and EX   */
/* -------------------------- */
PROC SORT DATA=WORK.SDTM_DM; BY USUBJID; RUN;
PROC SORT DATA=WORK.SDTM_EX; BY USUBJID; RUN;

DATA WORK.DM_EX_MERGE;
    MERGE WORK.SDTM_DM (IN=A)
          WORK.SDTM_EX (IN=B);
    BY USUBJID;

    IF A;

    /* Treatment Variables */
    LENGTH TRTP TRTA $50;
    IF EXTRT IN ("Placebo", "PBO") THEN DO;
        TRTP = "Placebo";
        TRTPN = 1;
    END;
    ELSE IF EXTRT IN ("Drug", "TRT") THEN DO;
        TRTP = "Drug";
        TRTPN = 2;
    END;
    ELSE DO;
        TRTP = "Other";
        TRTPN = 3;
    END;

    TRTA  = TRTP;
    TRTAN = TRTPN;

    KEEP USUBJID STUDYID SITEID SEX RACE ETHNIC AGE ARMCD ARM ACTARMCD ACTARM COUNTRY
         TRTP TRTPN TRTA TRTAN EXSTDTC EXENDTC;
RUN;

/* ---------------------------------- */
/* Step 4: Derive Serious AE Flag    */
/* ---------------------------------- */
PROC SQL;
    CREATE TABLE WORK.AE_FLAGS AS
    SELECT USUBJID,
           MAX(CASE WHEN AESER = "Y" THEN 1 ELSE 0 END) AS SERIOUS_AE_FLAG
    FROM WORK.SDTM_AE
    GROUP BY USUBJID;
QUIT;

DATA WORK.AE_FLAGS;
    SET WORK.AE_FLAGS;
    LENGTH AESER_FLAG $1;
    AESER_FLAG = IFC(SERIOUS_AE_FLAG = 1, "Y", "N");
    DROP SERIOUS_AE_FLAG;
RUN;

/* ----------------------------- */
/* Step 5: Build ADSL Dataset   */
/* ----------------------------- */
PROC SORT DATA=WORK.DM_EX_MERGE; BY USUBJID; RUN;
PROC SORT DATA=WORK.AE_FLAGS; BY USUBJID; RUN;

DATA WORK.ADSL;
    MERGE WORK.DM_EX_MERGE (IN=A)
          WORK.AE_FLAGS     (IN=B);
    BY USUBJID;
    IF A;

    /* Safety Population Flag */
    SAFFL = "Y"; /* Include all subjects for now */

    /* Treatment Dates & Duration */
    TRTSDT = DATEPART(EXSTDTC);
    TRTEDT = DATEPART(EXENDTC);
    FORMAT TRTSDT TRTEDT MMDDYY10.;

    IF NOT MISSING(TRTSDT) AND NOT MISSING(TRTEDT) THEN
        TRTDUR = TRTEDT - TRTSDT + 1;
    ELSE TRTDUR = .;

    /* Other Optional Variables */
    RANDFL = "N";  /* Assume not randomized in mock project */
    DS_AVAL = "";  /* Placeholder for disposition status */

    KEEP USUBJID STUDYID SITEID SEX RACE ETHNIC AGE ARMCD ARM ACTARMCD ACTARM COUNTRY
         TRTP TRTPN TRTA TRTAN TRTSDT TRTEDT TRTDUR SAFFL AESER_FLAG RANDFL DS_AVAL;
RUN;

/* ----------------------------------- */
/* Step 6: Add Labels and Descriptions */
/* ----------------------------------- */
PROC DATASETS LIBRARY=WORK NOLIST;
    MODIFY ADSL;
    LABEL
        USUBJID     = 'Unique Subject Identifier'
        STUDYID     = 'Study Identifier'
        SITEID      = 'Study Site Identifier'
        SEX         = 'Sex'
        RACE        = 'Race'
        ETHNIC      = 'Ethnicity'
        AGE         = 'Age at Informed Consent'
        ARMCD       = 'Planned Arm Code'
        ARM         = 'Planned Arm Description'
        ACTARMCD    = 'Actual Arm Code'
        ACTARM      = 'Actual Arm Description'
        COUNTRY     = 'Country'
        TRTP        = 'Planned Treatment'
        TRTPN       = 'Numeric Planned Treatment'
        TRTA        = 'Actual Treatment'
        TRTAN       = 'Numeric Actual Treatment'
        TRTSDT      = 'Date of First Dose'
        TRTEDT      = 'Date of Last Dose'
        TRTDUR      = 'Duration of Treatment (Days)'
        SAFFL       = 'Safety Population Flag'
        AESER_FLAG  = 'Serious Adverse Event (Any)'
        RANDFL      = 'Randomized Population Flag'
        DS_AVAL     = 'Disposition Status';
QUIT;

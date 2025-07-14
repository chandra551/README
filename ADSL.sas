/* Step 1: Import SDTM DM data */
PROC IMPORT OUT= WORK.SDTM_DM
            DATAFILE= "C:\path\to\raw_dm_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;

/* Step 2: Import SDTM AE data */
PROC IMPORT OUT= WORK.SDTM_AE
            DATAFILE= "C:\path\to\raw_ae_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;

/* Step 3: Simulate SDTM EX dataset if not available */
DATA WORK.SDTM_EX;
    SET WORK.SDTM_DM (KEEP=USUBJID RFSTDTC);
    EXTRT = "Drug"; /* Mock planned treatment */
    EXSTDTC = INPUT(RFSTDTC, ANYDTDTM.);
    EXENDTC = INTNX('DAY', EXSTDTC, 28); /* Assume 28-day treatment period */
    FORMAT EXSTDTC EXENDTC DATETIME20.;
RUN;

/* Step 4: Merge DM and EX datasets */
PROC SORT DATA=WORK.SDTM_DM;
    BY USUBJID;
RUN;

PROC SORT DATA=WORK.SDTM_EX;
    BY USUBJID;
RUN;

DATA WORK.DM_EX_MERGE;
    MERGE WORK.SDTM_DM (IN=A)
          WORK.SDTM_EX (IN=B);
    BY USUBJID;

    IF A;

    /* Derive TRTP and TRTPN */
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

    /* Actual Treatment Same as Planned */
    TRTA = TRTP;
    TRTAN = TRTPN;

    KEEP USUBJID STUDYID SITEID SEX RACE ETHNIC AGE ARMCD ARM ACTARMCD ACTARM COUNTRY TRTP TRTPN TRTA TRTAN EXSTDTC EXENDTC;
RUN;

/* Step 5: Derive AE Flags */
PROC SUMMARY DATA=WORK.SDTM_AE NWAY;
    CLASS USUBJID;
    VAR AESER;
    OUTPUT OUT=WORK.AE_SUMMARY (DROP=_TYPE_ _FREQ_)
           MAX(AESER) = AESER_MAX;
RUN;

DATA WORK.AE_FLAGS;
    SET WORK.AE_SUMMARY;
    IF AESER_MAX = "Y" THEN AESER_FLAG = "Y";
    ELSE AESER_FLAG = "N";
RUN;

/* Step 6: Merge with AE flags */
PROC SORT DATA=WORK.DM_EX_MERGE;
    BY USUBJID;
RUN;

PROC SORT DATA=WORK.AE_FLAGS;
    BY USUBJID;
RUN;

DATA WORK.ADSL;
    MERGE WORK.DM_EX_MERGE (IN=A)
          WORK.AE_FLAGS (IN=B);
    BY USUBJID;

    IF A;

    /* Safety Population Flag */
    SAFFL = "Y";

    /* Derived from EX */
    TRTSDT = DATEPART(EXSTDTC);
    TRTEDT = DATEPART(EXENDTC);
    FORMAT TRTSDT TRTEDT MMDDYY10.;

    /* Duration of Treatment in Days */
    TRTDUR = TRTEDT - TRTSDT + 1;

    /* Optional Variables */
    RANDFL = "N"; /* Not randomized */
    DS_AVAL = ""; /* Placeholder for disposition status */

    /* Keep only relevant variables */
    KEEP USUBJID STUDYID SITEID SEX RACE ETHNIC AGE ARMCD ARM ACTARMCD ACTARM COUNTRY
         TRTP TRTPN TRTA TRTAN TRTSDT TRTEDT TRTDUR SAFFL AESER_FLAG RANDFL DS_AVAL;
RUN;

/* Step 7: Label and format variables */
PROC DATASETS LIBRARY=WORK;
    MODIFY ADSL;
    LABEL
        USUBJID = 'Unique Subject Identifier'
        STUDYID = 'Study Identifier'
        SITEID = 'Study Site Identifier'
        SEX = 'Sex'
        RACE = 'Race'
        ETHNIC = 'Ethnicity'
        AGE = 'Age at Informed Consent'
        ARMCD = 'Planned Arm Code'
        ARM = 'Description of Planned Arm'
        ACTARMCD = 'Actual Arm Code'
        ACTARM = 'Description of Actual Arm'
        COUNTRY = 'Country'
        TRTP = 'Planned Treatment'
        TRTPN = 'Planned Treatment (Numeric)'
        TRTA = 'Actual Treatment'
        TRTAN = 'Actual Treatment (Numeric)'
        TRTSDT = 'Date of First Exposure to Treatment'
        TRTEDT = 'Date of Last Exposure to Treatment'
        TRTDUR = 'Duration of Treatment (Days)'
        SAFFL = 'Safety Population Flag'
        AESER_FLAG = 'Any Serious Adverse Event'
        RANDFL = 'Randomized Flag'
        DS_AVAL = 'Disposition Status';
RUN;
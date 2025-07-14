/* Step 1: Import SDTM datasets */
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

/* Step 2: Create dummy SDTM_EX dataset if not available */
DATA WORK.SDTM_EX;
    SET WORK.SDTM_DM (KEEP=USUBJID RFSTDTC);
    EXTRTP = "Drug"; /* Mock planned treatment */
    EXSTDTC = RFSTDTC; /* Assume first dose is reference start date */
    EXENDTC = INTNX('DAY', EXSTDTC, 28); /* Assume 28-day treatment period */
    FORMAT EXSTDTC EXENDTC DATETIME20.;
RUN;

/* Step 3: Merge DM, AE, and EX datasets */
PROC SORT DATA=WORK.SDTM_DM;
    BY USUBJID;
RUN;

PROC SORT DATA=WORK.SDTM_AE;
    BY USUBJID;
RUN;

PROC SORT DATA=WORK.SDTM_EX;
    BY USUBJID;
RUN;

DATA WORK.AE_MERGE;
    MERGE WORK.SDTM_AE (IN=A)
          WORK.SDTM_EX (IN=B)
          WORK.SDTM_DM (IN=C KEEP=USUBJID AGE SEX);
    BY USUBJID;

    IF A;

    /* Keep only relevant variables */
    KEEP USUBJID STUDYID AETERM AESTDTC AEENDTC AESEV AESER AEREL AEOUT
         EXTRTP EXSTDTC EXENDTC AGE SEX;
RUN;

/* Step 4: Derive ADaM variables */
DATA WORK.ADAE;
    SET WORK.AE_MERGE;

    /* ADaM Identifier Variables */
    LENGTH USUBJID $50 TRTP TRTA $200;

    USUBJID = USUBJID;
    TRTP = EXTRTP;
    TRTA = EXTRTP;

    /* Map numeric treatment group */
    IF TRTP = "Placebo" THEN TRTPN = 1;
    ELSE IF TRTP = "Drug" THEN TRTPN = 2;

    /* AE Topic Variables */
    AEBODSYS = ""; /* Not provided in raw data - map from dictionary if available */
    AETERM = AETERM;
    AESEV = AESEV;
    AESER = AESER;
    AEREL = AEREL;
    AVALC = AEOUT;

    /* Timing Variables */
    ASTDT = INPUT(AESTDTC, ANYDTDTM.);
    AENDT = INPUT(AEENDTC, ANYDTDTM.);
    FORMAT ASTDT AENDT DATETIME20.;

    /* Compute Study Days */
    IF NOT MISSING(ASTDT) AND NOT MISSING(EXSTDTC) THEN DO;
        ASTDY = CEIL((ASTDT - EXSTDTC)/86400);
        IF ASTDT >= EXSTDTC THEN ASTDY = ASTDY + 1;
    END;

    IF NOT MISSING(AENDT) AND NOT MISSING(EXSTDTC) THEN DO;
        AENDY = CEIL((AENDT - EXSTDTC)/86400);
        IF AENDT >= EXSTDTC THEN AENDY = AENDY + 1;
    END;

    /* Param Code */
    PARAMCD = "AE";

    /* Optional Flags */
    IF AESER = "Y" THEN SERIOUS = "Yes";
    ELSE SERIOUS = "No";

    /* Final Keep Statement */
    KEEP USUBJID TRTP TRTA TRTPN AEBODSYS AETERM AESEV AESER AEREL AVALC
         ASTDT ASTDY AENDT AENDY PARAMCD AGE SEX;
RUN;

/* Step 5: Label and Format ADaM Variables */
PROC DATASETS LIBRARY=WORK;
    MODIFY ADAE;
    LABEL
        USUBJID = 'Unique Subject Identifier'
        TRTP = 'Planned Treatment'
        TRTA = 'Actual Treatment'
        TRTPN = 'Numeric Version of Planned Treatment'
        AEBODSYS = 'Body System or Organ Class'
        AETERM = 'Adverse Event Term'
        AESEV = 'Severity'
        AESER = 'Serious Event'
        AEREL = 'Relationship to Study Drug'
        AVALC = 'Outcome of Adverse Event'
        ASTDT = 'Start Date of Adverse Event'
        ASTDY = 'Start Day Relative to First Dose'
        AENDT = 'End Date of Adverse Event'
        AENDY = 'End Day Relative to First Dose'
        PARAMCD = 'Parameter Code'
        AGE = 'Age at Informed Consent'
        SEX = 'Sex';
RUN;
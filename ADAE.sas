/* Step 1: Import SDTM Datasets */
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

/* Step 2: Create Mock SDTM_EX Dataset */
DATA WORK.SDTM_EX;
    SET WORK.SDTM_DM (KEEP=USUBJID RFSTDTC);
    
    /* Randomly assign treatment */
    IF MOD(_N_, 2) = 0 THEN EXTRTP = "Drug";
    ELSE EXTRTP = "Placebo";

    /* Set start date from RFSTDTC */
    EXSTDTC = INPUT(RFSTDTC, ANYDTDTM.);
    
    /* Add 28 days for treatment duration */
    IF NOT MISSING(EXSTDTC) THEN EXENDTC = EXSTDTC + 28*86400;
    
    FORMAT EXSTDTC EXENDTC DATETIME20.;
RUN;

/* Step 3: Sort Datasets for Merge */
PROC SORT DATA=WORK.SDTM_DM; BY USUBJID; RUN;
PROC SORT DATA=WORK.SDTM_AE; BY USUBJID; RUN;
PROC SORT DATA=WORK.SDTM_EX; BY USUBJID; RUN;

/* Step 4: Merge DM, AE, and EX */
DATA WORK.AE_MERGE;
    MERGE WORK.SDTM_AE (IN=A)
          WORK.SDTM_EX (IN=B)
          WORK.SDTM_DM (IN=C KEEP=USUBJID AGE SEX);
    BY USUBJID;
    
    IF A; /* Keep only AE records */

    /* Keep relevant variables */
    KEEP USUBJID STUDYID AETERM AESTDTC AEENDTC AESEV AESER AEREL AEOUT
         EXTRTP EXSTDTC EXENDTC AGE SEX;
RUN;

/* Step 5: Derive ADaM ADAE Dataset */
DATA WORK.ADAE;
    SET WORK.AE_MERGE;

    /* ADaM Treatment Variables */
    LENGTH TRTP TRTA $200 USUBJID $50 AEBODSYS $100 SERIOUS $5;

    TRTP = EXTRTP;
    TRTA = EXTRTP;

    /* Numeric Treatment */
    IF TRTP = "Placebo" THEN TRTPN = 1;
    ELSE IF TRTP = "Drug" THEN TRTPN = 2;

    /* Map AEBODSYS (mocked as example) */
    IF INDEX(UPCASE(AETERM), "HEADACHE") THEN AEBODSYS = "Nervous System Disorders";
    ELSE IF INDEX(UPCASE(AETERM), "RASH") THEN AEBODSYS = "Skin and Subcutaneous Tissue Disorders";
    ELSE AEBODSYS = "General Disorders";

    /* Severity, Seriousness, Relationship */
    AETERM = AETERM;
    AESEV = AESEV;
    AESER = AESER;
    AEREL = AEREL;
    AVALC = AEOUT;

    /* Convert dates to datetime */
    ASTDT = INPUT(AESTDTC, ANYDTDTM.);
    AENDT = INPUT(AEENDTC, ANYDTDTM.);
    FORMAT ASTDT AENDT DATETIME20.;

    /* Derive Study Day Variables */
    IF NOT MISSING(ASTDT) AND NOT MISSING(EXSTDTC) THEN DO;
        ASTDY = CEIL((ASTDT - EXSTDTC)/86400);
        IF ASTDT >= EXSTDTC THEN ASTDY = ASTDY + 1;
    END;

    IF NOT MISSING(AENDT) AND NOT MISSING(EXSTDTC) THEN DO;
        AENDY = CEIL((AENDT - EXSTDTC)/86400);
        IF AENDT >= EXSTDTC THEN AENDY = AENDY + 1;
    END;

    /* Flag Serious Events */
    IF AESER = "Y" THEN SERIOUS = "Yes";
    ELSE SERIOUS = "No";

    /* Assign Parameter Code */
    PARAMCD = "AE";

    /* Warning for missing dates */
    IF MISSING(EXSTDTC) THEN PUT "WARNING: Missing EXSTDTC for " USUBJID;
    IF MISSING(AESTDTC) THEN PUT "WARNING: Missing AESTDTC for " USUBJID;

    /* Final Keep */
    KEEP USUBJID TRTP TRTA TRTPN AEBODSYS AETERM AESEV AESER AEREL AVALC
         ASTDT ASTDY AENDT AENDY PARAMCD AGE SEX SERIOUS;
RUN;

/* Step 6: Label Variables */
PROC DATASETS LIBRARY=WORK NOLIST;
    MODIFY ADAE;
    LABEL
        USUBJID = 'Unique Subject Identifier'
        TRTP = 'Planned Treatment'
        TRTA = 'Actual Treatment'
        TRTPN = 'Numeric Treatment Code'
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
        SEX = 'Sex'
        SERIOUS = 'Serious Event Flag';
QUIT;

/* Step 1: Import raw lab data */
PROC IMPORT OUT= WORK.RAW_LB
            DATAFILE= "C:\path\to\raw_lb_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;

/* Step 2: Derive LB domain variables */
DATA WORK.SDTM_LB;
    SET WORK.RAW_LB;

    /* Identifier Variables */
    LENGTH STUDYID DOMAIN USUBJID $50;
    STUDYID = "HTN001";
    DOMAIN = "LB";
    USUBJID = USUBJID;

    /* Sequence Variable */
    LBSEQ = LBSEQ;

    /* Topic Variables */
    LBTEST = LBTEST;
    LBTESTCD = UPCASE(LBTEST); /* Standardized code */

    /* Category Mapping */
    IF INDEX(LBTEST, 'Hemoglobin') THEN LBCAT = 'HEMATOLOGY';
    ELSE IF INDEX(LBTEST, 'WBC') THEN LBCAT = 'HEMATOLOGY';
    ELSE IF INDEX(LBTEST, 'Platelet') THEN LBCAT = 'HEMATOLOGY';
    ELSE IF INDEX(LBTEST, 'Glucose') THEN LBCAT = 'CHEMISTRY';
    ELSE IF INDEX(LBTEST, 'Cholesterol') THEN LBCAT = 'CHEMISTRY';
    ELSE LBCAT = 'OTHER';

    /* Subcategory - optional */
    LBSCAT = ""; /* Not provided in raw data */

    /* Series */
    LBSERIES = LBTEST;

    /* Timing Variables */
    LBDTC = INPUT(LBDTC, ANYDTDTM.);
    FORMAT LBDTC DATETIME20.;
    
    /* Result Variables */
    LBORRES = LBORRES;
    LBORRESU = LBORRESU;
    LBSTRESN = LBSTRESN;
    LBSTRESU = LBSTRESU;

    /* Status */
    LBSTAT = "Final";

    /* Normal Range Indicator (example logic) */
    IF LBTEST = "Hemoglobin" AND LBSTRESN < 12 THEN LBNRIND = "L";
    ELSE IF LBTEST = "Hemoglobin" AND LBSTRESN > 16 THEN LBNRIND = "H";
    ELSE LBNRIND = "";
    /*  DM domain already exists as WORK.SDTM_DM with RFSTDTC */
PROC SORT DATA=WORK.SDTM_DM;
    BY USUBJID;
RUN;

PROC SORT DATA=WORK.SDTM_LB;
    BY USUBJID;
RUN;

DATA WORK.SDTM_LB_FINAL;
    MERGE WORK.SDTM_LB (IN=A)
          WORK.SDTM_DM (KEEP=USUBJID RFSTDTC);
    BY USUBJID;

    IF A;

    /* Calculate Study Day */
    IF NOT MISSING(LBDTC) AND NOT MISSING(RFSTDTC) THEN
        LBDY = CEIL((LBDTC - RFSTDTC)/86400); /* 86400 seconds/day */
    ELSE LBDY = .;

    /* Format Study Day */
    FORMAT LBDY BEST.;
RUN;

    /* Keep only relevant variables */
    KEEP STUDYID DOMAIN USUBJID LBSEQ LBTESTCD LBTEST LBCAT LBSCAT LBSERIES
         LBDTC LBDTCLAST LBORRES LBORRESU LBSTRESN LBSTRESU LBNRIND LBSTAT LBDY;
RUN;
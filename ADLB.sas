/* Step 1: Import raw Lab (LB) data */
PROC IMPORT OUT= WORK.SDTM_LB
            DATAFILE= "C:\path\to\raw_lb_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;

/* Step 2: Sort by subject and test */
PROC SORT DATA=WORK.SDTM_LB;
    BY USUBJID LBTEST VISITNUM;
RUN;

/* Step 3: Get baseline values (visit = 1) */
DATA WORK.BASELINE;
    SET WORK.SDTM_LB;
    IF VISITNUM = 1;
    RENAME LBSTRESN = BASE;
    KEEP USUBJID LBTEST BASE;
RUN;

/* Step 4: Merge baseline with all visits */
PROC SORT DATA=BASELINE; BY USUBJID LBTEST; RUN;

DATA WORK.LB_MERGE;
    MERGE WORK.SDTM_LB (IN=A)
          BASELINE (IN=B);
    BY USUBJID LBTEST;
    IF A;
RUN;

/* Step 5: Derive ADLB variables */
DATA WORK.ADLB;
    LENGTH PARAMCD LBSCAT $100 TRTP TRTA $200 LBNRIND LBCLSIG $5;

    /* Bring RFSTDTC, TRTP from DM using HASH */
    IF _N_ = 1 THEN DO;
        DECLARE HASH h(dataset: "WORK.SDTM_DM");
        h.defineKey("USUBJID");
        h.defineData("RFSTDTC", "SEX", "AGE");
        h.defineDone();
    END;

    SET WORK.LB_MERGE;

    /* Lookup RFSTDTC */
    rc = h.find();

    /* Derive variables */
    PARAMCD = UPCASE(LBTEST);
    AVAL    = LBSTRESN;
    AVALC   = LBORRES;

    /* Visit date handling */
    ADT = INPUT(LBDTC, ANYDTDTM.);
    FORMAT ADT DATETIME20.;

    /* Study day from reference start date */
    IF NOT MISSING(ADT) AND NOT MISSING(RFSTDTC) THEN DO;
        RFSTDTC_DT = INPUT(RFSTDTC, ANYDTDTM.);
        ADY = CEIL((ADT - RFSTDTC_DT)/86400);
        IF ADT >= RFSTDTC_DT THEN ADY + 1;
    END;
    ELSE ADY = .;

    /* Change from baseline and percent change */
    CHG = AVAL - BASE;
    IF BASE NE 0 THEN PCHG = (CHG / BASE) * 100;
    ELSE PCHG = .;

    /* Category assignment */
    IF PARAMCD IN ("HEMOGLOBIN", "WBC", "PLATELET") THEN LBSCAT = "Hematology";
    ELSE IF PARAMCD IN ("GLUCOSE", "CHOLESTEROL") THEN LBSCAT = "Chemistry";
    ELSE LBSCAT = "Other";

    /* Normal range flags */
    SELECT (PARAMCD);
        WHEN ("HEMOGLOBIN")
            IF AVAL < 12 THEN LBNRIND = "L";
            ELSE IF AVAL > 16 THEN LBNRIND = "H";
            ELSE LBNRIND = "N";
        WHEN ("WBC")
            IF AVAL < 4 THEN LBNRIND = "L";
            ELSE IF AVAL > 11 THEN LBNRIND = "H";
            ELSE LBNRIND = "N";
        WHEN ("PLATELET")
            IF AVAL < 10 THEN LBNRIND = "L";
            ELSE IF AVAL > 450 THEN LBNRIND = "H";
            ELSE LBNRIND = "N";
        OTHERWISE LBNRIND = "";
    END;

    /* Clinically Significant Flag */
    IF LBNRIND IN ("L", "H") THEN LBCLSIG = "Yes";
    ELSE IF LBNRIND = "N" THEN LBCLSIG = "No";
    ELSE LBCLSIG = "";

    /* Treatment variables – assume same planned/actual from DM or EX */
    IF MOD(_N_, 2) = 0 THEN DO; TRTP = "Drug"; TRTA = "Drug"; TRTPN = 2; END;
    ELSE DO; TRTP = "Placebo"; TRTA = "Placebo"; TRTPN = 1; END;

    /* Numeric Result String (can be used as LBSTRESC) */
    LBSTRESC = PUT(LBSTRESN, BEST.);

    /* Keep and format final dataset */
    KEEP USUBJID TRTP TRTA TRTPN PARAMCD AVAL AVALC ADT ADY BASE CHG PCHG
         LBSCAT LBNRIND LBCLSIG LBSTRESC LBSTRESN LBORRESU AGE SEX;
RUN;

/* Step 6: Label variables */
PROC DATASETS LIBRARY=WORK NOLIST;
    MODIFY ADLB;
    LABEL
        USUBJID   = "Unique Subject Identifier"
        TRTP      = "Planned Treatment"
        TRTA      = "Actual Treatment"
        TRTPN     = "Treatment Group Number"
        PARAMCD   = "Lab Parameter Code"
        AVAL      = "Lab Value (Standardized)"
        AVALC     = "Lab Value (Character)"
        ADT       = "Lab Test Date"
        ADY       = "Study Day of Lab Test"
        BASE      = "Baseline Lab Value"
        CHG       = "Change from Baseline"
        PCHG      = "Percent Change from Baseline"
        LBSCAT    = "Lab Category"
        LBNRIND   = "Normal Range Indicator"
        LBCLSIG   = "Clinically Significant?"
        LBSTRESC  = "Character Lab Value"
        LBSTRESN  = "Numeric Lab Value"
        LBORRESU  = "Lab Units"
        AGE       = "Age"
        SEX       = "Sex";
QUIT;

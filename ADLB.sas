/* Step 1: Import raw LB data */
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
DATA BASELINE;
    SET WORK.SDTM_LB;
    IF VISITNUM = 1;
    RENAME LBSTRESN = BASE;
    KEEP USUBJID LBTEST BASE;
RUN;

/* Step 4: Merge baseline with all visits */
PROC SORT DATA=BASELINE;
    BY USUBJID LBTEST;
RUN;

DATA WORK.LB_MERGE;
    MERGE WORK.SDTM_LB (IN=A)
          BASELINE (IN=B);
    BY USUBJID LBTEST;
    IF A;
RUN;

/* Step 5: Derive ADLB variables */
DATA WORK.ADLB;
    SET WORK.LB_MERGE;

    /* Identifier Variables */
    LENGTH USUBJID $50 PARAMCD $200;

    USUBJID = USUBJID;
    PARAMCD = UPCASE(LBTEST);

    /* Result Variables */
    AVAL = LBSTRESN;
    AVALC = LBORRES;

    /* Timing Variables */
    ADT = INPUT(LBDTC, ANYDTDTM.);
    FORMAT ADT DATETIME20.;

    /* Study Day Calculation (requires DM domain RFSTDTC) */
    IF _N_ = 1 THEN DO;
        DECLARE HASH h(dataset: 'WORK.SDTM_DM');
        h.defineKey('USUBJID');
        h.defineData('RFSTDTC');
        h.defineDone();
        CALL MISSING(RFSTDTC);
    END;

    rc = h.find();

    IF NOT MISSING(ADT) AND NOT MISSING(RFSTDTC) THEN
        ADY = CEIL((ADT - RFSTDTC)/86400); /* seconds/day */
    ELSE ADY = .;

    /* Change from Baseline */
    CHG = AVAL - BASE;

    /* Percent Change */
    IF BASE NE 0 THEN PCHG = (CHG / BASE) * 100;
    ELSE PCHG = .;

    /* Normal Range Indicators */
    SELECT(PARAMCD);
        WHEN("HEMOGLOBIN") DO;
            IF AVAL < 12 THEN LBNRIND = "L";
            ELSE IF AVAL > 16 THEN LBNRIND = "H";
            ELSE LBNRIND = "N";
        END;
        WHEN("WBC") DO;
            IF AVAL < 4 THEN LBNRIND = "L";
            ELSE IF AVAL > 11 THEN LBNRIND = "H";
            ELSE LBNRIND = "N";
        END;
        WHEN("PLATELET") DO;
            IF AVAL < 10 THEN LBNRIND = "L";
            ELSE IF AVAL > 450 THEN LBNRIND = "H";
            ELSE LBNRIND = "N";
        END;
        OTHERWISE LBNRIND = "";
    END;

    /* Clinically Significant Flag */
    IF LBNRIND IN ("L", "H") THEN LBCLSIG = "Yes";
    ELSE LBCLSIG = "No";

    /* Optional Mapping */
    LBSTRESC = LBSTRESN; /* Already numeric */

    /* Category Mapping */
    IF INDEX("HEMOGLOBIN WBC PLATELET", PARAMCD) THEN LBSCAT = "Hematology";
    ELSE IF INDEX("GLUCOSE CHOLESTEROL", PARAMCD) THEN LBSCAT = "Chemistry";
    ELSE LBSCAT = "Other";

    /* Keep only relevant variables */
    KEEP USUBJID TRTP TRTA PARAMCD AVAL AVALC ADT ADY BASE CHG PCHG
         LBSCAT LBNRIND LBCLSIG LBSTRESC LBSTRESN LBORRESU;
RUN;
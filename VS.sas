/* Step 1: Import raw VS data */
PROC IMPORT OUT= WORK.RAW_VS
            DATAFILE= "C:\path\to\raw_vs_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;

/* Step 2: Derive SDTM VS domain */
DATA WORK.SDTM_VS;
    SET WORK.RAW_VS;

    /* Identifier Variables */
    LENGTH STUDYID DOMAIN USUBJID $50;
    STUDYID = "HTN001";
    DOMAIN = "VS";
    USUBJID = USUBJID;

    /* Topic Variables */
    VSTESTCD = UPCASE(VSTESTCD); /* Standardize test code */
    VSTEST = VSTEST;

    /* Sequence Variable */
    VSSEQ = _N_; /* Simple incrementing sequence */

    /* Result Variables */
    VSORRES = VSORRES;
    VSORRESU = VSORRESU;
    VSSTRESC = INPUT(VSORRES, BEST12.);
    VSSTRESU = VSORRESU;

    /* Timing Variables */
    VSDTC = INPUT(VSDTC, ANYDTDTM.);
    FORMAT VSDTC DATETIME20.;

    /* Study Day (requires merge with DM) */
    IF _N_ = 1 THEN DO;
        /* Load RFSTDTC from DM dataset */
        DECLARE HASH h(dataset: 'WORK.SDTM_DM');
        h.defineKey('USUBJID');
        h.defineData('RFSTDTC');
        h.defineDone();
        CALL MISSING(RFSTDTC);
    END;

    rc = h.find();

    IF NOT MISSING(VSDTC) AND NOT MISSING(RFSTDTC) THEN
        VSDY = CEIL((VSDTC - RFSTDTC)/86400); /* seconds/day */
    ELSE VSDY = .;

    /* Optional Variables */
    SELECT(VSTESTCD);
        WHEN("SYSBP", "DIABP") VSPARCAT = "Blood Pressure";
        WHEN("PULSE") VSPARCAT = "Heart Rate";
        OTHERWISE VSPARCAT = "Other";
    END;

    /* Flag for AE association (example logic) */
    IF INDEX(VSTEST, "BLOOD PRESSURE") > 0 THEN VSAEFL = "Y";
    ELSE VSAEFL = "N";
    PROC SORT DATA=WORK.SDTM_DM;
    BY USUBJID;
RUN;

PROC SORT DATA=WORK.SDTM_VS;
    BY USUBJID;
RUN;

DATA WORK.SDTM_VS_FINAL;
    MERGE WORK.SDTM_VS (IN=A)
          WORK.SDTM_DM (KEEP=USUBJID RFSTDTC);
    BY USUBJID;

    IF A;

    /* Recalculate study day after merge */
    IF NOT MISSING(VSDTC) AND NOT MISSING(RFSTDTC) THEN
        VSDY = CEIL((VSDTC - RFSTDTC)/86400);

    FORMAT VSDY BEST.;
RUN;

    KEEP STUDYID DOMAIN USUBJID VSSEQ VSTESTCD VSTEST
         VSORRES VSORRESU VSSTRESC VSSTRESU VSDTC VSDY
         VSPARCAT VSAEFL;
RUN;
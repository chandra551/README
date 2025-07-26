/* --------------------------- */
/* Step 1: Simulated SDTM_VS  */
/* --------------------------- */
DATA WORK.SDTM_VS;
    INFILE DATALINES DLM=",";

    INPUT USUBJID $ VSTESTCD $ VSTEST $ VSORRES $ VSORRESU $ VSSTRESC $ VSSTRESN BEST12.
          VSDTC :DATETIME20. VSDY BEST8.;

    FORMAT VSDTC DATETIME20.;
DATALINES;
HTN001-003-001,SYSBP,Systolic BP,145,mmHg,145,145,20JAN2024:00:00,10
HTN001-003-001,DIABP,Diastolic BP,95,mmHg,95,95,20JAN2024:00:00,10
HTN001-003-001,PULSE,Heart Rate,78,bpm,78,78,20JAN2024:00:00,10
HTN001-001-002,SYSBP,Systolic BP,150,mmHg,150,150,15JAN2024:00:00,15
HTN001-001-002,DIABP,Diastolic BP,90,mmHg,90,90,15JAN2024:00:00,15
HTN001-001-002,PULSE,Heart Rate,80,bpm,80,80,15JAN2024:00:00,15
;
RUN;

/* ------------------------------- */
/* Step 2: Sort by subject & test  */
/* ------------------------------- */
PROC SORT DATA=WORK.SDTM_VS; 
    BY USUBJID VSTESTCD VSDTC; 
RUN;

/* -------------------------------------- */
/* Step 3: Get Baseline per Subject/Test  */
/* -------------------------------------- */
DATA WORK.BASELINE;
    SET WORK.SDTM_VS;
    BY USUBJID VSTESTCD;

    IF FIRST.VSTESTCD THEN DO;
        BASE = VSSTRESN;
        OUTPUT;
    END;
    KEEP USUBJID VSTESTCD BASE;
RUN;

/* ------------------------------ */
/* Step 4: Merge Baseline to VS   */
/* ------------------------------ */
PROC SORT DATA=WORK.BASELINE; 
    BY USUBJID VSTESTCD; 
RUN;

DATA WORK.VS_MERGE;
    MERGE WORK.SDTM_VS (IN=A)
          WORK.BASELINE (IN=B);
    BY USUBJID VSTESTCD;
    IF A;
RUN;

/* ----------------------------------------- */
/* Step 5: Derive ADVS (Analysis Dataset)    */
/* ----------------------------------------- */
DATA WORK.ADVS;
    LENGTH PARAMCD $20 VSPARCAT VSCAT $50 TRTP TRTA $20;

    /* Load RFSTDTC from DM via hash */
    IF _N_ = 1 THEN DO;
        DECLARE HASH h(dataset: "WORK.SDTM_DM");
        h.defineKey("USUBJID");
        h.defineData("RFSTDTC");
        h.defineDone();
    END;

    SET WORK.VS_MERGE;

    /* Get reference start date */
    rc = h.find();
    RFSTDTC_DT = INPUT(RFSTDTC, ANYDTDTM.);

    /* Identifier variables */
    PARAMCD = UPCASE(VSTESTCD);
    AVAL = VSSTRESN;
    ADT = VSDTC;

    /* Study Day */
    IF NOT MISSING(ADT) AND NOT MISSING(RFSTDTC_DT) THEN DO;
        ADY = CEIL((ADT - RFSTDTC_DT) / 86400);
        IF ADT >= RFSTDTC_DT THEN ADY + 1;
    END;
    ELSE ADY = .;

    /* Change from baseline */
    CHG = AVAL - BASE;
    IF BASE NE . AND BASE NE 0 THEN PCHG = (CHG / BASE) * 100;
    ELSE PCHG = .;

    /* Treatment group simulation (real would use EX or DM/ARMCD) */
    IF MOD(_N_, 2) = 0 THEN DO; TRTP = "Drug"; TRTA = "Drug"; END;
    ELSE DO; TRTP = "Placebo"; TRTA = "Placebo"; END;

    /* Vital sign categorization */
    SELECT (PARAMCD);
        WHEN ("SYSBP", "DIABP") DO;
            VSPARCAT = "Blood Pressure";
            VSCAT = "Cardiovascular";
        END;
        WHEN ("PULSE", "RESP") DO;
            VSPARCAT = "Heart Rate";
            VSCAT = "Cardiovascular";
        END;
        WHEN ("TEMP") DO;
            VSPARCAT = "Temperature";
            VSCAT = "General";
        END;
        OTHERWISE DO;
            VSPARCAT = "Other";
            VSCAT = "Other";
        END;
    END;

    /* Final keep */
    KEEP USUBJID TRTP TRTA PARAMCD AVAL ADT ADY BASE CHG PCHG
         VSPARCAT VSCAT VSTEST VSORRESU VSSTRESN VSSTRESC;
RUN;

/* --------------------------------------- */
/* Step 6: Label and Format ADVS Dataset   */
/* --------------------------------------- */
PROC DATASETS LIBRARY=WORK NOLIST;
    MODIFY ADVS;
    LABEL
        USUBJID   = "Unique Subject Identifier"
        TRTP      = "Planned Treatment"
        TRTA      = "Actual Treatment"
        PARAMCD   = "Vital Signs Parameter Code"
        AVAL      = "Numeric Result (Standardized)"
        ADT       = "Date of Measurement"
        ADY       = "Study Day"
        BASE      = "Baseline Value"
        CHG       = "Change from Baseline"
        PCHG      = "Percent Change from Baseline"
        VSPARCAT  = "Vital Signs Parent Category"
        VSCAT     = "Vital Signs Category"
        VSTEST    = "Vital Signs Test Name"
        VSORRESU  = "Original Result Units"
        VSSTRESN  = "Standardized Numeric Result"
        VSSTRESC  = "Standardized Character Result";
QUIT;

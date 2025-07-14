/* Step 1: Simulate SDTM_VS dataset if not available */
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

/* Step 2: Sort by subject and test */
PROC SORT DATA=WORK.SDTM_VS;
    BY USUBJID VSTEST VISITNUM;
RUN;

/* Step 3: Get baseline values (visit = 1) */
DATA BASELINE;
    SET WORK.SDTM_VS;
    IF VISITNUM = 1;
    RENAME VSSTRESN = BASE;
    KEEP USUBJID VSTEST BASE;
RUN;

/* Step 4: Merge baseline with all visits */
PROC SORT DATA=BASELINE;
    BY USUBJID VSTEST;
RUN;

DATA WORK.VS_MERGE;
    MERGE WORK.SDTM_VS (IN=A)
          BASELINE (IN=B);
    BY USUBJID VSTEST;
    IF A;
RUN;

/* Step 5: Derive ADVS variables */
DATA WORK.ADV;
    SET WORK.VS_MERGE;

    /* Identifier Variables */
    LENGTH USUBJID $50 PARAMCD $200;

    USUBJID = USUBJID;
    PARAMCD = UPCASE(VSTESTCD);

    /* Result Variables */
    AVAL = VSSTRESN;

    /* Timing Variables */
    ADT = INPUT(VSDTC, ANYDTDTM.);
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

    /* Category Mapping */
    IF INDEX("SYSBP DIABP", PARAMCD) THEN DO;
        VSPARCAT = "Blood Pressure";
        VSCAT = "Cardiovascular";
    END;
    ELSE IF INDEX("PULSE RESPIRATION", PARAMCD) THEN DO;
        VSPARCAT = "Heart Rate";
        VSCAT = "Cardiovascular";
    END;
    ELSE IF INDEX("TEMPERATURE", PARAMCD) THEN DO;
        VSPARCAT = "Temperature";
        VSCAT = "General";
    END;
    ELSE DO;
        VSPARCAT = "Other";
        VSCAT = "Other";
    END;

    /* Keep only relevant variables */
    KEEP USUBJID TRTP TRTA PARAMCD AVAL ADT ADY BASE CHG PCHG
         VSPARCAT VSCAT VSTEST VSORRESU VSSTRESN VSSTRESC;
RUN;

/* Step 6: Label and format variables */
PROC DATASETS LIBRARY=WORK;
    MODIFY ADV;
    LABEL
        USUBJID = 'Unique Subject Identifier'
        TRTP = 'Planned Treatment'
        TRTA = 'Actual Treatment'
        PARAMCD = 'Parameter Code'
        AVAL = 'Numeric Vital Sign Result'
        ADT = 'Analysis Date'
        ADY = 'Study Day'
        BASE = 'Baseline Value'
        CHG = 'Change from Baseline'
        PCHG = 'Percent Change from Baseline'
        VSPARCAT = 'Parent Category'
        VSCAT = 'Category'
        VSTEST = 'Test Name'
        VSORRESU = 'Units'
        VSSTRESN = 'Numeric Result'
        VSSTRESC = 'Standardized Result';
RUN;
/* Step 1: Import the raw AE data */
PROC IMPORT OUT= WORK.RAW_AE
            DATAFILE= "C:\path\to\raw_ae_data_hypertension.xlsx"
            DBMS=EXCEL REPLACE;
     SHEET="Sheet1";
     GETNAMES=YES;
RUN;
/* Step 1: Import the raw AE2 data */
DATA MEDDRA_MOCK;
    LENGTH AETERM $50 AEDECOD AEBODSYS AEHLT AEHLGT AELLT $100;

    INPUT AETERM $ AEDECOD $ AEBODSYS $ AEHLT $ AEHLGT $ AELLT $;
    DATALINES;
Hypertension Hypertension Vascular Disorders Vascular Disorders General Vascular Terms LLT_Hypertension
Headache Headache Nervous System Disorders Neurological Disorders Central Nervous System LLT_Headache
Nausea Nausea Gastrointestinal Disorders GI Symptoms GI Events LLT_Nausea
Dizziness Dizziness General Disorders Dizziness Events General LLT_Dizziness
Fatigue Fatigue General Disorders Fatigue Events General LLT_Fatigue
Palpitations Palpitations Cardiac Disorders Cardiovascular Events Cardiac LLT_Palpitations
;
RUN;

/* Step 2: Derive SDTM AE domain */
DATA WORK.SDTM_AE;
    SET WORK.RAW_AE;

    /* Identifier Variables */
    LENGTH STUDYID DOMAIN USUBJID AESPID $50;

    STUDYID = "HTN001";
    DOMAIN = "AE";
    USUBJID = USUBJID;
    AESEQ = AESEQ;
    AESPID = AESPID;

    /* Topic Variables */
    AETERM = AETERM;
    AEDECOD = ""; /* Not available in raw data */
    AEBODSYS = ""; /* Not available in raw data */
    AECAT = ""; /* Not available in raw data */

    /* Record Qualifier Variables */
    IF AESER = "Y" THEN AESER = "Y"; ELSE AESER = "N";
    AEACN = AEACN;
    AEREL = AEREL;
    AEOUT = AEOUT;
    AESEV = AESEV;

    /* Timing Variables */
    AESTDTC = INPUT(AESTDTC, ANYDTDTM.);
    AEENDTC = INPUT(AEENDTC, ANYDTDTM.);
    FORMAT AESTDTC AEENDTC DATETIME20.;
    PROC SORT DATA=WORK.SDTM_DM;
    BY USUBJID;
RUN;

PROC SORT DATA=WORK.SDTM_AE;
    BY USUBJID;
RUN;

DATA WORK.SDTM_AE_FINAL;
    MERGE WORK.SDTM_AE(IN=A)
          WORK.SDTM_DM(KEEP=USUBJID RFSTDTC);
    BY USUBJID;

    IF A;

    /* Derive Study Days */
    IF NOT MISSING(AESTDTC) AND NOT MISSING(RFSTDTC) THEN
        AESTDY = CEIL((AESTDTC - RFSTDTC) / 86400); /* 86400 seconds per day */
    ELSE AESTDY = .;

    IF NOT MISSING(AEENDTC) AND NOT MISSING(RFSTDTC) THEN
        AEENDY = CEIL((AEENDTC - RFSTDTC) / 86400);
    ELSE AEENDY = .;

    FORMAT AESTDY AEENDY BEST.;
RUN;
PROC SORT DATA=RAW_AE;
    BY AETERM;
RUN;

PROC SORT DATA=MEDDRA_MOCK;
    BY AETERM;
RUN;

DATA SDTM_AE_DERIVED;
    MERGE RAW_AE (IN=A)
          MEDDRA_MOCK (IN=B);
    BY AETERM;

    IF A;

    /* Default values if no match found in mock dictionary */
    IF AEDECOD = "" THEN DO;
        AEDECOD = AETERM;
        AEBODSYS = "UNK";
        AEHLT = "UNK";
        AEHLGT = "UNK";
        AELLT = "UNK";
    END;

    /* AECAT – Category assignment (simple rule-based logic) */
    IF INDEX(AETERM, "Headache") OR INDEX(AETERM, "Dizziness") THEN AECAT = "Neurological Events";
    ELSE IF INDEX(AETERM, "Nausea") OR INDEX(AETERM, "Fatigue") THEN AECAT = "Gastrointestinal Events";
    ELSE IF INDEX(AETERM, "Palpitations") OR INDEX(AETERM, "Hypertension") THEN AECAT = "Cardiovascular Events";
    ELSE AECAT = "Other";

    /* Assign placeholder codes */
    AEPTCD = _N_; /* Simulated PT Code */
    AEBDSYCD = ROUND(RANUNI(1)*1000); /* Random SOC Code */
    AEHLTCD = ROUND(RANUNI(1)*1000); /* Random HLT Code */
    AEHLGTCD = ROUND(RANUNI(1)*1000); /* Random HLGT Code */
    AELLTCD = ROUND(RANUNI(1)*1000); /* Random LLT Code */

    KEEP STUDYID DOMAIN USUBJID AESEQ AESPID AETERM AEDECOD AEBODSYS AECAT
         AEHLT AEHLGT AELLT AEPTCD AEBDSYCD AEHLTCD AEHLGTCD AELLTCD;
RUN;

    /* Keep only relevant variables */
    KEEP STUDYID DOMAIN USUBJID AESEQ AESPID AETERM AEDECOD AEBODSYS AECAT
         AESER AEACN AEREL AEOUT AESEV AESTDTC AEENDTC;
RUN;
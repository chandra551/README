libname abc xlsx "/home/u63555562/clinical sas/adsl_adae_raw_example.xlsx";
proc copy in=abc out= work; run;
libname abc clear;
* creates 2 tables adsl data and adae data;
*...............................................................................................................;
 data raw1;
 set work.adae_raw;
 trt=trta01n;
 where saffl="Y" and trtemfl="Y" ;
 run;
  data raw2;
 set work.adsl;
 trt=trt01an;
 where saffl="Y"  ;
 run;
 *merging both dataset for furthur analysis;

 data merge1;
 merge raw1
 raw2;
 by usubjid ;
 run;
 *getting trt total;
 proc sql;
 create table total as select trt,count(distinct usubjid) as Trt_total from merge1
 group by trt;
 quit;
 */if trt had missing or 0 freq counts for any trt lvl with accordance to mock 
 shell we would use dummy dataset to match like if a and not b then trt total=0 but this is not the case now so 
 we continue */;
 *........................................................................................................;
 *creating macrovarible to populate count as per mock shell;
 data _null_;
 set total;
 call symputx(cats("n",trt),Trt_total);run;
 *creating the upper(overall) section of the summary table;
 proc sql;
 create table upper as select "overall" as label length=50,trt,count(distinct usubjid)
 as counts from raw1 group by trt; quit;
 *creating the lower(preferred term) section of the summary table;
 proc sql;
 create table lower as select aedecod,trt,count(distinct usubjid)
 as counts from merge1 group by  aedecod,trt; quit;
 *merging both the upper and lower counts;
 data merge2;
 set work.upper work.lower;
 run;
*subsetting  the preffered term  to merge it furthur;
proc sort data=lower out= pt nodupkey;
by aedecod ; run;
*calculate percentage and do formatting for 4 subject;
data merge3;
set merge2  total;
run;
*....................................................................................................;
data cp  ;
set merge3(obs=6) ;
if not missing(counts) then do;
cp=put(counts,3.)||"("|| put(counts/&n1.*100,5.1)||")";
end;
else do;
cp= put(counts,3.); end; run;
*merging distinct total count per trt with cp var to assign variable;

*assigning labels;
data lab;
set cp;
if missing(aedecod) then label=label; ord=1; output;
 if not missing(aedecod) and missing(label) then label=strip(aedecod);ord=2;output;
run;
*some more formatting.........................;
data lol;
set lab;
if missing(label) then delete;output;
drop Trt_total;
 run;
 proc sort data=lol out= temp nodupkey;
by  trt label;run;
*transposing;
 proc sort data=temp;
by  ord label  ; run;
proc transpose data= temp out=tempf prefix=trt;
by ord label;
var cp;
id trt; run;
data final;
set tempf;
array x(2)trt1 trt2;
do i= 1 to dim(x);
if missing(x(i)) then x(i)=0; end; drop i ;run;
*report writing;
 ods rtf file="/home/u63555562/clinical sas/tlf03.rtf";
title"ADVERSE EVENT BY PREFERRED TERM";
title2"FULL ANALYSIS  AND TREATMENT EMERGENCE SET";
proc report data=final center headline headskip nowd split='~' missing 
		style(report)=[just=center] style(header)=[just=center];
column  label ord  trt1 trt2 ;
	define ord /order noprint;
	define label/width=30 "PREFERRED TERM" order style(column)=[cellwidth=1.2in 
		 protectspecialcharacters=off] style(header)=[just=left];
	define trt1/order "DRUG"  " N=&n1." style(column)=[cellwidth=1.2in just=center];
	define trt2/"PLACEBO" " N=&n2." style(column)=[cellwidth=1.2in just=center];

run;

ods rtf close;

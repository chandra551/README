proc import datafile="/home/u63555562/EPG1V2/data/adsl.xlsx" out=adsl dbms=xlsx 
		replace;
run;

*filter data according to condition given;

data adsl1;
	set adsl;
	where fasfl="Y";
run;

*replicate the existing rows and create total column using output syntax;

data adsl2;
	set adsl1;
	treatment=trt01pn;
	treatmentc=trto1p;
	output;
	treatment="4";
	treatmentc="total";
	output;
run;

*create a format for all trt lvl;
;

proc format;
	value trt 1=1 2=2 3=3 4=4;
run;

*obtain required desc using proc summary and apply format;

proc summary data=adsl2 nway completetypes;
	class treatment/preloadfmt;
	var age;
	output out=stat1 n=nmiss=mean=std=min=q1=median=q3=max=/autoname;
	format treatment trt.;
run;

*process and round off stat acc to requirement even buildng concatinating vars;

data stat2;
	set stat1;
	length n nmiss mean std min q1 median q3 max $30.;

	if age_mean ne . then
		mean=put(age_mean, 5.1);
	else
		age_mean="-";

	if age_stdDev ne . then
		std=put(age_mean, 5.1);
	else
		age_stdDev="-";

	if age_Median ne . then
		median=put(age_Median, 5.1);
	else
		age_Median="-";
	nmiss=put(age_N, 3.1) ||"("||(put(age_NMiss, 3.1))||")";

	if age_N ne 0 then
		do;
			mean_std=trim(put(age_Mean, 5.2)) || "("||trim(put(age_stdDev, 5.2))||")";
			q1q3=trim(age_Q1) || "("|| trim(age_Q3)||")";
			minmax=trim(age_Min) ||trim( "("|| trim(age_Max)||")");
		end;
run;

*create dataset out of stat2 to keep only required varible;

data stat3;
	set stat2;
array x(5)nmiss mean_std q1q3 minmax Median;
do i=1 to dim(x);
if missing(x(i)) then x(i)=0; end; 
	
	keep treatment Median std nmiss mean_std q1q3 minmax;
run;

*sorting data and restructure the data;

proc sort data=stat3;
	by treatment;
run;

proc transpose data=stat3 out=trans;
	by treatment;
	var Median nmiss mean_std q1q3 minmax;
run;

*create vars according to the presentation reqirement;

data stat5;
	set trans;
	group=1;
	length group_label stat $30.;
	group_label="age(years)";

	if _name_="nmiss" then
		do;
			odr=1;
			stat="n(missing)";
		end;

	if _name_="mean_std" then
		do;
			odr=2;
			stat="mean(std)";
		end;

	if _name_="q1q3" then
		do;
			odr=3;
			stat="q1(q3)";
		end;

	if _name_="minmax" then
		do;
			odr=4;
			stat="minimum(maximum)";
		end;

	if _name_="median" then
		do;
			odr=5;
			stat="MEDIAN";
		end;
run;

*final restructure the data according to the shell requirement;

proc sort data=stat5;
	by group_label odr stat treatment;
run;

proc transpose data=stat5 out=stat6 prefix=trt;
	by group group_label odr stat;
	var col1;
	id treatment;
run;

*create final datasheet;

data final;
	set stat6;
	drop _name_;
run;

*report generation and rtf file preperation;
ods rtf file="/home/u63555562/clinical sas/tlf1.rtf" style=csgpool01;
title "Descriptive statistics for age varible";
title2 color=aquamarine "full analysis set";

proc report data=final center headline headskip nowd split='~' missing 
		style(report)=[just=center] style(header)=[just=center];
	column group group_label odr stat trt1 trt2 trt3 trt4;
	define group /order noprint;
	define odr/order noprint;
	define group_label/width=30 "" order style(column)=[cellwidth=1.2in 
		protectspecialcharacters=off] style(header)=[just=left];
	define stat/width=30 "STATISTICS" order style(column)=[cellwidth=1.2in 
		protectspecialcharacters=off] style(header)=[just=left];
	define trt1/"Dose level 1" style(column)=[cellwidth=1.2in just=center];
	define trt2/"Dose level 2" style(column)=[cellwidth=1.2in just=center];
	define trt3/"Dose level 3" style(column)=[cellwidth=1.2in just=center];
	define trt4/"Total" style(column)=[cellwidth=1.2in just=center];
run;

ods rtf close;
data raw;
set work.adsl;
run;
 ods rtf file="/home/u63555562/clinical sas/tlf3.rtf";
 title1 "abc company";
 title2"full analysis set";
footnote justify=left"fasfl=Y";
proc report data=raw nowd headline center split='|' style={outputwidth=100%} style(header)={justify=center}  ;
columns usubjid age trto1p obs;
define obs/order noprint;
define usubjid/"name"
style(column)={cellwidth=33% just=left}
style(header)={cellwidth=33% just=center};
define age/"age"'|'"per subject"
style(column)={cellwidth=33% just=left}
style(header)={cellwidth=33% just=center};
define trto1p/"treatment level"
style(column)={cellwidth=30% just=left}
style(header)={cellwidth=30% just=center};
run;
ods rtf close;



%macro work();
proc sql noprint;
select distinct path into: path
from dictionary.libnames
where libname="WORK";
quit;
%put WORK LIBRARY LOCATED AT - &PATH;
%mend work;

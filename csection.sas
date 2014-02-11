%macro csection(vars,year,month,lib);

/*Predefinitions*/
options minoperator;
%local vars year month lib dsn;
%if %upcase(&vars)=HELP %then %do;
	%put NOTE: *************************HELP FOR THE %nrstr(%CSECTION) MACRO*******************************;
	%put NOTE- This Macro pulls a cross-section from SIPP datasets given a specific month and year.;
	%put NOTE- Common ID variables are included along with user-defined additions in the call      ;
	%put NOTE-      Call as: %nrstr(%csection)(Desired Variables, Year, Month, Output Library)        		;
	%put NOTE-           		    Ex %nrstr(%csection)(EAST1A EAST2A,2005,10,SIPPWORK)           			;
	%put NOTE- *************************Thank you, the macro will now terminate*******************************;
	%return;
%end;
%if &lib= %then %do;
	%let lib=work;
	%put WARNING: **************************************************************************;
	%put WARNING- Output library not specified, output dataset will be sent to WORK library.;
	%put WARNING-                Call %nrstr(%csection(help)) for more info                 ;
	%put WARNING- *****************************Thank you************************************;
%end;
/*Extracting Data*/
%if &year in 2008 2009 2010 2011 %then %do;
	%do i=1 %to 12;		
			%if %sysfunc(exist(SIPP08&i..ppmpuw&i)) %then %do;
				Data &lib..temp&i;
				set sipp08&i..ppmpuw&i;
				keep SSUID EPPPNUM SWAVE SPANEL SROTATON RHCALMN RHCALYR EOUTCOME EAGE ESEX ERACE EORIGIN EMS EHHNUMPP ETENURE EEDUCATE WPFINWGT RPTOTINC RPEARN RHTOTINC GMETRO &vars;
				where rhcalyr=&year and %upcase(rhcalmn)=%upcase(&month);
				run;
			%end;
	%end;
%end;
%if &year in 2004 2005 2006 2007 %then %do;
	%do i=1 %to 12;		
			%if %sysfunc(exist(SIPP08&i..ppmpuw&i)) %then %do;
				Data &lib..temp&i;
				set sipp04&i..ppmpuw&i;
				keep SSUID EPPPNUM SWAVE SPANEL SROTATON RHCALMN RHCALYR EOUTCOME EAGE ESEX ERACE EORIGIN EMS EHHNUMPP ETENURE EEDUCATE WPFINWGT RPTOTINC RPEARN RHTOTINC GMETRO &vars;
				where rhcalyr=&year and %upcase(rhcalmn)=%upcase(&month);
				run;
			%end;
	%end;
%end;
/*Combinging Temporaries*/ 
%let dsn=output;
%let i=0;
%if %sysfunc(exist(&lib..&dsn)) %then %do %until (%sysfunc(exist(&lib..&dsn))=0);
	%let i=%eval(&i+1);
	%let dsn=output&i;
%end;
data &lib..&dsn;
set %do i=1 %to 12;		
		%if %sysfunc(exist(&lib..temp&i)) %then %do;
			&lib..temp&i
		%end;
	%end;
	;
run;
/*Resorting Variables*/
data &lib..&dsn;
retain SSUID EPPPNUM SWAVE SPANEL SROTATON RHCALMN RHCALYR EOUTCOME EAGE ESEX ERACE EORIGIN EMS EHHNUMPP ETENURE EEDUCATE WPFINWGT RPTOTINC RPEARN RHTOTINC GMETRO &vars;
set &lib..&dsn;
run;
/*Delete Temporaries*/
proc datasets library=&lib;
   delete %do i=1 %to 12;		
				%if %sysfunc(exist(&lib..temp&i)) %then %do;
					%upcase(temp&i)
				%end;
		  %end;
		  ;
run;
%mend csection;

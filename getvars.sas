%macro getvars(lib,data,prefix);
%global returnvars;
%local lib data prefix;
proc sql;
	select name label="Retrieved Vars" into :returnvars separated by " " 
	from dictionary.columns 
	where libname=%upcase("&lib") and memname=%upcase("&data") and %upcase(NAME) contains %upcase("&prefix");
quit;
%mend getvars;

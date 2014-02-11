%macro find(prefix, lib);
%local prefix lib;
proc sql;
select name,type,memname,libname
from dictionary.columns
where %upcase(name) contains %upcase("&prefix") and %upcase(libname) contains %upcase("&lib")
order by libname, memname, name;
quit;
%mend find;

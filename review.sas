/*SAS Macro for automated visualization for data review*/

%macro review (dataset= , variables= , weight= , by=, globif= , subif= , id= , forcecat= , forcecont= , thresh=56, negthresh=10, report=PDF);

			************************************;
			/*	   Check version	   */
			************************************;

%if %sysevalf(&sysver < 9) %then %do;
   %put SAS 9 or later is required.  Program will terminate.;
   %goto exit;
%end;

			************************************;
			/*      Creating PDF REPORT file   */
			************************************;

				ODS listing close;
				ODS graphics on;
				options orientation=landscape FORMCHAR="|----|+|---+=|-/\<>*" nodate nonumber nolabel;	

%local baton varlist vars;

title;
	
			************************************;
			/*      Decompose data input       */
			************************************;

%let library=%scan(&dataset,1,".");

%let member=%scan(&dataset,2,".");

%let varlist=; /*Start list as empty to prevent recurssion*/

	%if &variables eq %then %do;   /*add something to catch "all"*/

		proc sql noprint;
			select name into :varlist separated by " "
				from dictionary.columns
					where libname = %upcase("&library") and memname=%upcase("&member");
		quit;

	%end; /*end put all dataset vars into macro*/
	
	%else %do; /*if varlist is not empty then do*/

		%let k=1;
		%let varname = %scan(&variables, &k,' ');
		%do %while ("&varname" NE "");

			/*need to add: check for existence of variable*/

			/*if has colon, then sql*/
			
			%if %substr(&varname,%length(&varname))=: %then %do;  /*write to allow for other characters, such as dashes*/	

						proc sql noprint;
						select name into :vars separated by " "
							from dictionary.columns
								where libname = %upcase("&library") and memname=%upcase("&member") and name like ("%upcase(%scan(&varname,1,:))%");
						quit;

						%let varlist = &varlist &vars;
						%symdel vars;

			%end; /*End varname refers to multiple vars*/
			%else %do;

						%let varlist=&varlist &varname;

			%end;  /*End varname is full name*/


		%let k = %eval(&k + 1);
		%let varname = %scan(&variables, &k,' ');
		%end; /*End decomposition of variable inputs*/

	%end; /*End varlist is not empty*/

%put varlist: &varlist; /*for testing**************/


			***********************************************************;
			/*			Create formats			  */
			***********************************************************;
							proc format;
								value describe .00000000001 - high = ">0";
								value positivenegative low -  -.0000000000001 = "<0"
							   .00000000001 - high = ">0";
							   value starts 1="A-Z" 2="0-9" 3="OTHER";
							   value contains 1="A-Z only" 2="0-9 only" 3="A-Z & 0-9" 4="OTHER";
							run;


			**********************************************************;
			/*	           Declare Report File			 */
			**********************************************************;

				ODS escapechar="^" noproctitle;
				ODS PDF file="LPANELTEST_92.PDF" contents=no color=yes style=journal notoc;


			***********************************************************;
			/*		 Begin variable loop			  */
			***********************************************************;

	%let k=1;
	%let varname = %scan(&varlist, &k,' ');
	%do %while ("&varname" NE "");

	%let data=&dataset;	/*to reset data macro after possible conversion in character section*/

	ODS layout start;

			***********************************************************;
			/*    Create categorical/continuous variable indicator    */
			***********************************************************;

		proc sql noprint;
			create table temp as select distinct strip(&varname) from &data; 
			select count(&varname) into :count from temp;
		quit;

		%if &count < &thresh %then %let FLAG=1;
		%else %let FLAG=0;


			***************************************;
			/*  If categorical variable, then do  */
			***************************************;
			
			%if &FLAG=1 %then %do;

				/*Make character for better output*/
				data tempchar;
					set &data. (keep=&varname %if &weight ne %then &weight; );
					&varname._char=put(strip(&varname),$32.);
					where &globif %if &subif ne %then and &varname &subif; ;
					if strip(&varname._char) in ("",".") then &varname._char="MISSING";
				run;

ODS region width=11in height=1.5in x=-.2in y=0in; *HEADER;

				ODS pdf text="^S={just=center font_weight=bold font_size=22pt font_face=Arial}Variable: &varname";
				ODS pdf text="^S={just=center font_size=18pt font_face=Arial}Classified as: Categorical";

ODS region width=11in height=7in x=0in y=.75in; *body;

				proc gchart	data=tempchar;
					hbar &varname._char / descending;	
					%if &weight ne %then weight &weight; ;
					where &globif %if &subif ne %then and &varname &subif; ;
				run;

			%end; /*End categorical variable*/

			%else %do; 
			***************************************;
			/*  If continuous variable, then do   */
			***************************************;
		
			/*Determine the variable format*/
			
						proc sql noprint;
							select type into :type
								from dictionary.columns
									where libname = %upcase("&library") and memname=%upcase("&member") and upcase(name)=%upcase("&varname");
						quit;

	
				%if &type = num %then %do; /*Begin section of numeric continuous data*/

%numpath:
	
						proc sql noprint;
							create table temp_lt0 as select distinct &varname from &data where &varname < 0;
							select count(&varname) into :countneg from temp_lt0;
							
							create table temp_0 as select &varname from &data where &varname = 0;
							select count(&varname) into :countzero from temp_0;
						quit;

%put negative count for &varname: &countneg; /*For testing*/ 
%put zero count for &varname: &countzero; /*For testing*/ 


				*************************************************************************;
				/* If not many negative numbers, then do  (Indicates certain survey data)*/
				*************************************************************************;

					%if &countneg < &negthresh %then %do;

ODS region width=11in height=.75in x=-.2in y=0in; *HEADER;

						ODS pdf text="^S={just=center font_weight=bold font_size=22pt font_face=Arial}Variable: &varname";/* , ^S={font_size=18pt}Classified as: Continuous"; */	
						ODS pdf text="^S={just=center font_size=18pt font_face=Arial}Classified as: Continuous";
						%if &countneg>0 %then ODS pdf text="^S={just=center font_size=18pt}(including 0's)";;


ODS region width=5.125in height=4in x=0in y=.75in ; *TOP LEFT;

						proc univariate data=&data;
							ODS select Histogram;
							var &varname;
							histogram &varname;
							where &varname >= 0;
						run;
					
ODS region width=5.125in height=4in x=5.25in y=.75in ; *TOP RIGHT;

						proc univariate data=&data;
							ODS select qqplot;
							var &varname;
							qqplot &varname / normal(mu=est sigma=est l=1 w=5 );
							where &varname >= 0;
						run;

ODS region width=5.125 in height=5in x=0in y=4.75in; *BOTTOM LEFT;

						ODS pdf text="^S={just=center font_weight=bold font_size=12pt}Summary Statistics:";

						proc means data=&data min q1 median q3 max mean std n missing;
							var &varname;
							weight &weight;
							where &varname >= 0;
							ODS select summary;
							format &varname best.;
						run;

ODS region width=5.125 in height=5in x=5.25in y=4.75in; *BOTTOM RIGHT;

						ODS pdf text="^S={just=center font_weight=bold font_size=12pt}Universe Checks:";
						ODS pdf text="^S={just=center font_weight=bold font_size=12pt}This section show the count of all distinct non-positive values, and all values >0";

						title Universe/Sanity Checks for &varname;				
							proc freq data=&data;
								tables &varname / list missing;
								ODS select OneWayFreqs;
								format &varname describe.;
							run;
						title;


						%if &countzero > 0 %then %do; /*Begin > 0 section of continuous variable with not many negative numbers*/

							ODS layout end;	
							ODS layout start;

							ODS pdf text="^S={just=center font_weight=bold font_size=22pt}Variable: &varname"; 	
							ODS pdf text="^S={just=center font_weight=bold font_size=18pt}Classified as: Continuous";
							ODS pdf text="^S={just=center font_size=18pt}(excluding 0's)";


ODS region width=5.125in height=6in x=0in y=.5in ; *TOP LEFT;

							proc univariate data=&data;
								ODS select Histogram;
								var &varname;
								histogram &varname;
								where &varname > 0;
							run;
					
ODS region width=5.125in height=4in x=5.25in y=.5in ; *TOP RIGHT;

							proc univariate data=&data;
								ODS select qqplot;
								var &varname;
								qqplot &varname / normal(mu=est sigma=est l=1 w=5 );
								where &varname > 0;
							run;

ODS region width=5.125in height=4in x=0in y=3.75in; *BOTTOM LEFT;

							ODS pdf text="^S={just=center font_size=12pt}Summary Statistics:";

							proc means data=&data min q1 median q3 max mean std n missing;
								var &varname;
								weight &weight;
								where &varname > 0;
							run;

ODS region width=5.125in height=6in x=5.25in y=3.75in; *BOTTOM RIGHT;

							ODS pdf text="^S={just=center font_size=12pt}Universe Checks:";
							ODS pdf text="^S={just=center font_size=12pt}This section show the count of all distinct non-positive values, and all values >0";

							proc freq data=&data;
								tables &varname / list missing;
								ODS select OneWayFreqs;
								format &varname describe.;
							run;

						%end; /*End > 0 section of continuous variable with not may negative numbers*/

					%end; /*End continuous variable with not many negative numbers*/

					%else %do; /*Begin continuous variable with many negative numbers*/

						ODS pdf text="^S={just=center font_weight=bold font_size=22pt}Variable: &varname"; 	
						ODS pdf text="^S={just=center font_weight=bold font_size=18pt}Classified as: Continuous";

ODS region width=5.125in height=4in x=0in y=0in ; *TOP LEFT;

							proc univariate data=&data;
								ODS select Histogram;
								var msrp;
								histogram msrp;
							run;
						title;

ODS region width=5.125in height=4in x=5.25in  y=0in ; *TOP RIGHT;

							proc freq data=&data;
								tables &varname / list missing;
								format &varname positivenegative.;
								weight &weight;
							run;

ODS region width=5.125in height=4in x=0in y=3.75in; *BOTTOM LEFT;

							proc means data=&data min q1 median q3 max mean st n missing;
								var &varname;
								weight &weight;
							run;

ODS region width=5.125in height=4in x=5.25in y=3.75in; *BOTTOM RIGHT;

							proc univariate data=&data
								ODS select QQPLOT;
								var &varname;
								qqplot &varname / normal(mu=est sigma=est l=1 w=5 );
							run;

					%end; /*End continous variable with many negative numbers*/

				%end; /*End section of continuous variabe with num format*/

				%else %do; /*Do continuous variable with character format*/
	
	**************************************************************;
	/* Begin section of continuous variable with character format */
	**************************************************************;
	
					/*Check if data is a mix of numbers or characters*/
						
					data desc_temp_numchar;
						set &data (keep=&varname);
							
							call symputx('baton',&varname,'L');
							%put baton: &baton;
							&varname._type=resolve('%DATATYP(&baton)');
							if &baton not in (".","");

					run;

					proc sql noprint;
						create table temp as select distinct &varname._type from desc_temp_numchar;
						select count(&varname._type), &varname._type into :ctypes, :types from temp;
					quit;

%put count of types for &varname: &ctypes; /*for testing*/
%put types for &varname: &types;	


	************************************************************************************;
	/* Begin section of continuous variable with character format and all numeric data */
	************************************************************************************;

					%if (&ctypes=1 and &types=NUMERIC) %then %do;  

%charnum:

						data &data._num(rename=(&varname.char=&varname));
							set &data(keep=&varname);
								&varname.char=input(&varname,best32.);
								if &varname.char ne .;
								drop &varname;
						run;

						%let data=&data._num;
						%goto numpath;
								
					%end; /*end continuous variable with character format and all numeric data*/

					%else %do; 

					****************************************************************************************;
					/* Begin section of continuous variable with character format and not all numeric data */
					****************************************************************************************;
								/*do a freq with formats, sample values on one page*/
								/*if any numeric, send it down the num path, or back up to previous if statement*/		

						data desc_temp_char (keep=starts_with contains &varname);
							set &data (keep=&varname);
			
							st_&varname=substr(strip(&varname),1,1);

							if ANYALPHA(st_&varname)>0 then Starts_with=1;
							else if ANYDIGIT(st_&varname)>0 then Starts_with=2;
							else if ANYPUNCT(st_&varname)=1 then Starts_with=3;
							else starts_with=4;

							if ( ANYALPHA(&varname)>0 and ANYDIGIT(&varname)>0 ) then Contains=3;
							else if ANYALPHA(&varname)>0 then Contains=1;
							else if ANYDIGIT(&varname)>0 then Contains=2;
							else Contains=4;

						run;

						ODS pdf text="^S={just=center font_face=Arial font_weight=bold font_size=22pt}Variable: &varname"; 	
						ODS pdf text="^S={just=center font_face=Arial font_size=18pt}Classified as: Continuous";
						ODS pdf text="^S={just=center font_face=Arial font_size=18pt}(with character format)";


ODS region width=5.5in height=8in x=0in y=1in ; *LEFT;

						ODS pdf text="^S={just=center font_weight=bold font_size=12pt}Frequency of what the values start with, and what they contain:"; 	

						proc freq data=desc_temp_char;
							tables starts_with*contains / list missing;
							format starts_with starts. contains contains.;
						run;	

ODS region width=5.5in height=8in x=5.5in y=1in; *RIGHT;

						ODS pdf text="^S={just=center font_weight=bold font_size=12pt}Random Sample of Values:"; 	

						proc sql noprint;
							create table desc_sample as
								select distinct A.*
								from desc_temp_char as A
								where RANUNI(0) between .45 and .55 ;
						quit;

						title Random Sample of Values for &varname;
						proc print data = desc_sample(obs=25) noobs ;
						format starts_with starts. contains contains.;
						run;
						title;					

						%if &ctypes=2 %then %do; 

								ODS layout end;
								ODS layout start;
								%goto charnum;

						%end; /*End numeric data present in character format check*/

					%end; /*End section of continuous variable with character format and not all numeric data*/ 

				%end; /*End continous variable with character format*/

			%end; /*End continuous variable*/

	ODS layout end;

	/*	%symdel count countzero countneg type;*/

				****************************************;
				/* End of loop, scan for next variable */
				****************************************;

	%let k = %eval(&k + 1);
	%let varname = %scan(&varlist, &k,' ');
	%end;



				/*System clean-up*/
/*%symdel vars;*/
ODS layout end;
ODS pdf close;
ODS listing;

title;

%exit:
%mend review;

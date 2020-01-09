*** version 3.0 9January2020
*** contact information: plus1@sogang.ac.kr

program nscale
	version 10
	syntax varlist(numeric) [, REPLACE Generate(namelist) PREfix(name) POSTfix(name) Extract(numlist max=1) NUMbering(numlist max=1) SEParator Interactive Quietly Missing(numlist max=1) Up Down Reverse Tabulate]

// qui {

	*** check if options are correctly specified
		if ( "`generate'"!="" | "`prefix'"!="" | "`postfix'"!="" ) & "`replace'"!="" {
			di as error "option generate(), prefix() or postfix() may not be combined with replace"
			exit 198			
		}
		if ( "`extract'"!="" | "`numbering'"!="" ) & "`generate'"=="" {
			di as error "option extract() or numbering() requires generate() to be set"
			exit 198
		}
		if "`missing'"!="" & "`interactive'"!="" {
			di as error "option interactive may not be combined with missing()"
			exit 198
		}
		if "`up'"!="" & "`down'"!="" {
			di as error "option up may not be combined with down"
			exit 198
		}
		if ( "`up'"!="" | "`down'"!="" ) & "`missing'"=="" {
			di as error "option up or down requires missing() to be set"
			exit 198
		}

	*** print warnings {
		if "`extract'"!="" & "`numbering'"!="" {
			di as result "option extract() combined with numbering() might not give the desired result"
		}
		if "`prefix'"=="" & "`postfix'"=="" & "`separator'"!="" {
			di as result "option separator only applies if prefix() or postfix() is set"
		}
		if "`interactive'"=="" & "`quietly'"!="" {
			di as result "option quietly only applies if nscale is running in interactive mode"
		}

	*** get number of variables
		local counted : word count `varlist'

	*** check if nubmer of variables and number of names match
		if ( "`extract'"!="" | "`numbering'"!="" ) & `counted'>1 & `: word count `generate''==1 {
			local generate="`generate' "*(`counted'-1)+"`generate'"
		}
		if "`generate'"!="" {
			if `counted'<`: word count `generate'' {
				di as error "option generate():	too many names specified"
				exit 103
			}
			else if `counted'>`: word count `generate'' {
				di as error "option generate():	too few names specified"
				exit 103
			}
		}

	*** options applied before naming
		if "`separator'"!="" {
			local sep "_"
		}
		else {
			local sep ""
		}

	*** start loop to name variables
		forval i=1/`counted' {
			local var : word `i' of `varlist'
			local nscale_var "`var'"
			if "`replace'"=="" {
			* replace: off
				if "`generate'"!="" {
				* generate: on
					local gen : word `i' of `generate'
					local nscale_var "`gen'"
				}
				if "`prefix'"!="" {
				* prefix: on
					local nscale_var="`prefix'"+"`sep'"+"`nscale_var'"
				}
				if "`postfix'"!="" {
				* postfix: on
					local nscale_var="`nscale_var'"+"`sep'"+"`postfix'"
				}
				if "`extract'"!="" {
				* extract: on
					nscale_extract `var' , e(`extract')
					if "`s(nscale_extract)'"!="error" {
						local nscale_var="`nscale_var'"+"`s(nscale_extract)'"
					}
					else {
						local nscale_var=subinstr("`nscale_var'", "`gen'", "`var'", .)
					}
				}
				if "`numbering'"!="" {
				* numbering: on
					local num=`numbering'-1+`i'
					local digit=strlen("`counted'")
					local num : display %0`digit'.0f `num'
					local nscale_var="`nscale_var'"+"`num'"
				}
				if "`var'"=="`nscale_var'" {
					local nscale_var "`nscale_var'_01"
				}
			}
			local nscale_varlist="`nscale_varlist'"+" `nscale_var'"
		}

	*** options applied before scaling
		if "`interactive'"!="" & "`quietly'"=="" {
		* interactive: on, quietly: off
			di as text "nscale interactive mode is running"
			di as text "각 변수마다 빈도표를 확인하고 결측치로 설정할 값을 지정할 수 있습니다."
			di as text "Available options in interactive mode are as follows: up down reverse tab"
		}

	*** start loop to scale variables to lie between 0 and 1
		forval i=1/`counted' {
			local var : word `i' of `varlist'
			local nscale_var : word `i' of `nscale_varlist'
			if "`interactive'"=="" {
			* interactive: off
				nscale_replace `var' `nscale_var' , `replace' m(`missing') `up' `down' `reverse' `tabulate'
			}
			else {
			* interactive: on
				local nscale_label : value label `var'
				numlabel `nscale_label' , add
				noisily tab `var'
				nscale_interactive `var' `nscale_var' , `replace' `reverse' `tabulate'
				if ( "`tabulate'"!="" | "`s(nscale_interactive_tabulate)'"!="" ) {
					di as text "계속하려면 엔터 키를 누르세요: " , _request(_interacted_tabulate)
				}
			}
		}

// }

end

program nscale_interactive
	version 10
	syntax namelist(max=2) [, REPLACE Reverse Tabulate]

// qui {

	*** get variable names
		gettoken var nscale_var : namelist

	*** specify missing values interactively
		di as text "결측치로 지정할 값을 입력하세요: " , _request(_interacted)
		if "`interacted'"=="exit" {
			exit 1
		}
		capture noisily: nscale_interactive_options `interacted'
		if _rc==0 {
			gettoken interacted interacted_options : interacted , p(",")
			if "`interacted'"=="," {
				local interacted ""
			}
			local interacted_options=subinstr("`interacted_options'", ",", "", .)
			if "`reverse'"!="" & "`s(nscale_interactive_reverse)'"=="" {
				local interacted_options="`interacted_options'"+" `reverse'"
			}
			if "`tabulate'"!="" & "`s(nscale_interactive_tabulate)'"==""  {
				local interacted_options="`interacted_options'"+" `tabulate'"	
			}
			nscale_replace `var' `nscale_var' , `replace' m(`interacted') `interacted_options'
		}
		else {
			nscale_interactive `var' `nscale_var' , `replace' `reverse' `tabulate'
		}

// }

end

program nscale_interactive_options , sclass
	version 10
	syntax [anything(name=missing)] [, Up Down Reverse Tabulate]

// qui {

	sreturn local nscale_interactive_reverse ""
	sreturn local nscale_interactive_tabulate ""

	*** check if specified value is numeric
		if "`missing'"!="" {
			capture confirm number `missing'
			if _rc!=0 {
				di as error "You should specify a number"
				exit 198
			}
		}

	*** check if options are correctly specified
		if "`up'"!="" & "`down'"!="" {
			di as error "option up may not be combined with down"
			exit 198
		}
		else if ( "`up'"!="" | "`down'"!="" ) & "`missing'"=="" {
			di as error "option up or down requires to specify value"
			exit 198
		}

	*** check if reverse or tabulate has been specified locally
		if "`reverse'"!="" {
			sreturn local nscale_interactive_reverse "`reverse'"
		}
		if "`tabulate'"!="" {
			sreturn local nscale_interactive_tabulate "`tabulate'"
		}

// }

end

program nscale_replace
	version 10
	syntax namelist(max=2) [, REPLACE Missing(numlist min=0 max=1) Up Down Reverse Tabulate]

qui {

	*** get variable names
		if "`replace'"=="" {
		* replace: off
			gettoken given_var var : namelist
			clonevar `var' = `given_var'
		}
		else {
		* replace: on
			local var "`1'"
		}
		label values `var' .

	*** scale variable to lie between 0 and 1
		if "`missing'"!="" {
		* missing: on
			if "`up'"!="" & "`down'"=="" {
			* up: on, down: off
				summarize `var' if `var'<`missing'
				replace `var'=(`var'-r(min))/(r(max)-r(min)) if `var'<`missing'
				replace `var'=. if `var'>=`missing'
			}
			else if "`up'"=="" & "`down'"!="" {
			* up: off, down: on
				summarize `var' if `var'>`missing'
				replace `var'=(`var'-r(min))/(r(max)-r(min)) if `var'>`missing'
				replace `var'=. if `var'<=`missing'
			}
			else {
			* up and down: off
				summarize `var' if `var'!=`missing'
				replace `var'=(`var'-r(min))/(r(max)-r(min)) if `var'!=`missing'		
				replace `var'=. if `var'==`missing'
			}
		}
		else {
		* missing: off
			summarize `var'
			replace `var'=(`var'-r(min))/(r(max)-r(min))
		}

	*** options
		if "`reverse'"!="" {
			replace `var'=1-`var'
		}
		if "`tabulate'"!="" {
			noisily tab `var'
		}

}

end

program nscale_extract , sclass
	version 10
	syntax varlist(max=1) , Extract(integer)

qui {

	sreturn local nscale_extract ""
	if round(c(stata_version))>13 {
	* running Stata newer than 13
		local extracted=usubstr("`varlist'", ustrlen("`varlist'")+1-`extract', `extract')
	}
	else {
	* running Stata older than 14
		local extracted=substr("`varlist'", strlen("`varlist'")+1-`extract', `extract')
	}
	capture confirm number `extracted'
	if _rc==0 {
		sreturn local nscale_extract "`extracted'"
	}
	else {
		if `extract'>1 {
			local extract=`extract'-1
			nscale_extract `varlist' , e(`extract')
		}
		else {
			sreturn local nscale_extract "error"
			exit
		}
	}

}

end

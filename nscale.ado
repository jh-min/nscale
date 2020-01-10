*** version 3.0 11January2020
*** contact information: plus1@sogang.ac.kr

program nscale
	version 10
	syntax varlist [, REPLACE Generate(namelist) PREfix(name) POSTfix(name) SEParator Extract(numlist max=1) noLZero NUMbering(numlist max=1) FORCE DIstinct(integer 30) Interactive Quietly Missing(numlist max=1) Up Down Reverse Tabulate]

qui {

	*** check if options are correctly specified
		if ( "`generate'"!="" | "`prefix'"!="" | "`postfix'"!="" ) & "`replace'"!="" {
			noisily di as error "option {bf:generate()}, {bf:prefix()} or {bf:postfix()} may not be combined with {bf:replace}"
			exit 198			
		}
		if ( "`extract'"!="" | "`numbering'"!="" ) & "`generate'"=="" {
			noisily di as error "option {bf:extract()} or {bf:numbering()} requires {bf:generate()} to be set"
			exit 198
		}
		if "`force'"!="" & "`distinct'"!="" {
			noisily di as error "option {bf:force} may not be combined with {bf:distinct}"
			exit 198
		}
		if "`missing'"!="" & "`interactive'"!="" {
			noisily di as error "option {bf:missing()} may not be combined with {bf:interactive mode}"
			exit 198
		}
		if "`up'"!="" & "`down'"!="" {
			noisily di as error "option {bf:up} may not be combined with {bf:down}"
			exit 198
		}
		if ( "`up'"!="" | "`down'"!="" ) & "`missing'"=="" {
			noisily di as error "option {bf:up} or {bf:down} requires {bf:missing()} to be set"
			exit 198
		}

	*** print warnings {
		if "`extract'"!="" & "`numbering'"!="" {
			noisily di as error "option {bf:extract()} combined with {bf:numbering()} might not give the desired result"
		}
		if "`prefix'"=="" & "`postfix'"=="" & "`separator'"!="" {
			noisily di as error "option {bf:separator} only applies if {bf:prefix()} or {bf:postfix()} is set"
		}
		if "`numbering'"=="" & "`lzero'"=="nolzero" {
			noisily di as error "option {bf:nolzero} only applies if {bf:numbering()} is set"
		}
		if "`interactive'"=="" & "`quietly'"!="" {
			noisily di as error "option {bf:quietly} only applies if {bf:nscale} is running in {bf:interactive mode}"
		}

	*** get number of variables
		local counted : word count `varlist'

	*** check if nubmer of variables and number of names match
		if ( "`extract'"!="" | "`numbering'"!="" ) & `counted'>1 & `: word count `generate''==1 {
			local generate="`generate' "*(`counted'-1)+"`generate'"
		}
		if "`generate'"!="" {
			if `counted'<`: word count `generate'' {
				noisily di as error "option {bf:generate()}:	too many names specified"
				exit 103
			}
			else if `counted'>`: word count `generate'' {
				noisily di as error "option {bf:generate()}:	too few names specified"
				exit 103
			}
		}

	*** options applied before naming variables
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
						if round(c(stata_version))>13 {
						* running Stata newer than 13
							local nscale_var=usubinstr("`nscale_var'", "`gen'", "`var'", .)
						}
						else {
						* running Stata older than 14
							local nscale_var=subinstr("`nscale_var'", "`gen'", "`var'", .)
						}
					}
				}
				if "`numbering'"!="" {
				* numbering: on
					local num=`numbering'-1+`i'
					local digit=strlen("`counted'")
					if "`lzero'"!="nolzero" {
					* lzero: on
						local num : display %0`digit'.0f `num'
					}
					local nscale_var="`nscale_var'"+"`num'"
				}
				if "`var'"=="`nscale_var'" {
				* no naming options are specified
					local nscale_var "`nscale_var'_01"
				}
			}
			local nscale_varlist="`nscale_varlist'"+" `nscale_var'"
		}

	*** options applied before scaling variables
		if "`interactive'"!="" {
		* interactive: on
			local hlinesize=round((c(linesize)-strlen(" nscale (interactive mode) "))/2)
			if "`quietly'"=="" {
			* quietly: off
				noisily di as text "{hline `hlinesize'} {cmd:nscale} (interactive mode) {hline}"
				if c(linesize)<92 {
					noisily di as text "Specify a value being set to missing (.) for each variable," _newline " with a comma followed by options"
				}
				else {
					noisily di as text "Specify a value being set to missing (.) for each variable, with a comma followed by options"	
				}
				if c(linesize)<67 {
					noisily di as text "Available options in interactive mode are:" _newline " {cmd:up} {cmd:down} {cmd:reverse} {cmd:tabulate}"
				}
				else {
					noisily di as text "Available options in interactive mode are: {cmd:up} {cmd:down} {cmd:reverse} {cmd:tabulate}"	
				}
				noisily di as text "{hline}"
			}
		}

	*** start loop to scale variables
		forval i=1/`counted' {
			local var : word `i' of `varlist'
		*** check if given variable is able to be scaled
			if strmatch("`: type `var''", "str*")==1 {
				noisily di as error "{bf:nscale} skips scaling {bf:`var'}: string variable"
				continue
			}
			summarize `var'
			if r(N)==0 {
				noisily di as error "{bf:nscale} skips scaling {bf:`var'}: no observations"
				continue
			}
			else if r(min)==r(max) {
				noisily di as error "{bf:nscale} skips scaling {bf:`var'}: constant variable"
				continue
			}
		*** options applied before subprograms
			if "`force'"=="" & ( strpos("`0'", "*")==1 | `counted'>30 ) {
			* force: off
				levelsof `var'
				if r(r)>`distinct' {
					noisily di as error "{bf:nscale} skips scaling {bf:`var'}: number of distinct values exceeded `distinct'"
					continue
				}
			}
		*** call subprograms
			local nscale_var : word `i' of `nscale_varlist'
			if "`interactive'"=="" {
			* interactive: off
				nscale_scale `var' `nscale_var' , `replace' m(`missing') `up' `down'
			}
			else {
			* interactive: on
				numlabel `: value label `var'' , add force
				noisily tab `var'
				noisily di _newline as text "{hline `hlinesize'} {cmd:nscale} (interactive mode) {hline}"
				capture noisily nscale_interactive `var' `nscale_var' , `replace'
				while _rc!=0 & _rc!=1 {
					capture noisily nscale_interactive `var' `nscale_var' , `replace'
				}
				if _rc==1 {
					noisily di as text "{cmd:nscale} has been terminated by {search r(1),local:user request}"
					noisily di as text "{hline}"
					continue , break
				}
				noisily di as text "{hline}"
			}
		*** options applied after subprograms
			if "`reverse'"!="" | "`s(nscale_options_reverse)'"!=""  {
				replace `nscale_var'=1-`nscale_var'
			}
			if "`tabulate'"!="" | "`s(nscale_options_tabulate)'"!="" {
				noisily tab `nscale_var'
				if "`interactive'"!="" {
					noisily di as text _newline "Press {mansection R moreRemarksandexamples:any key} to continue, or {help keyboard:Break} to abort {cmd:nscale} {hline}"
					set more on
					more
					set more off			
				}
			}
		}

}

end

program nscale_interactive
	version 10
	syntax namelist(max=2) [, REPLACE]

qui {

	*** get variable names
		gettoken var nscale_var : namelist

	*** specify missing values interactively
		noisily di as text "Enter a value being set to missing (.): " _request(_interacted)
		if "`interacted'"=="exit" {
			exit 1
		}
		capture noisily nscale_options `interacted'
		if _rc!=0 {
			exit _rc
		}
		nscale_scale `var' `nscale_var' , `replace' m(`s(nscale_options_missing)') `s(nscale_options_up)' `s(nscale_options_down)'
}

end

program nscale_options , sclass
	version 10
	syntax [anything(name=missing)] [, Up Down Reverse Tabulate]

qui {

	sreturn local nscale_options_missing ""
	sreturn local nscale_options_up ""
	sreturn local nscale_options_down ""
	sreturn local nscale_options_reverse ""
	sreturn local nscale_options_tabulate ""

	*** check if specified value is numeric
		if "`missing'"!="" {
			capture confirm number `missing'
			if _rc!=0 {
				noisily di as error "You should specify a number"
				exit 198
			}
			sreturn local nscale_options_missing "`missing'"
		}

	*** check if options are correctly specified
		if "`up'"!="" & "`down'"!="" {
			noisily di as error "option {bf:up} may not be combined with {bf:down}"
			exit 198
		}
		else if ( "`up'"!="" | "`down'"!="" ) & "`missing'"=="" {
			noisily di as error "You should specify a value to set option {bf:up} or {bf:down}"
			exit 198
		}

	*** store options
		if "`up'"!="" {
			sreturn local nscale_options_up "`up'"
		}
		if "`down'"!="" {
			sreturn local nscale_options_up "`down'"
		}
		if "`reverse'"!="" {
			sreturn local nscale_options_reverse "`reverse'"
		}
		if "`tabulate'"!="" {
			sreturn local nscale_options_tabulate "`tabulate'"
		}

}

end

program nscale_scale
	version 10
	syntax namelist(max=2) [, REPLACE Missing(numlist min=0 max=1) Up Down]

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
		}
	}

}

end

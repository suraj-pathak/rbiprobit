*! version 1.0.0 , 13aug2021
*! Author: Mustafa Coban, Institute for Employment Research (Germany)
*! Website: mustafacoban.de
*! Support: mustafa.coban@iab.de


/****************************************************************/
/*     rbiprobit margdec: rbiprobit postestimation command		*/
/****************************************************************/



/* MARGINS */
program define rbiprobit_margdec, eclass
	
	version 14
	syntax [anything] [if] [in] [, *]
	
	if ("`e(cmd)'" != "rbiprobit") error 301
	
	*! safe `0'
	local origin  "`0'"		
	
	
	*!	parse original rbiprobit
	local rbipr_cmdl = "`e(cmdline)'"
	local 0: subinstr local rbipr_cmdl "rbiprobit" "", word
	
	gettoken dep1 0 : 0, parse(" =,[")
	
	
	
	*!	Allow "=" after depvar	
	gettoken equals rest : 0, parse(" =")
	if "`equals'" == "=" { 
		local 0 `"`rest'"'
	}		
	
	*! parse indepvars
	syntax [varlist(numeric default=none ts fv)] [if] [in] , /*
			*/ ENDOGenous(string) [ * ]
			
	local indep1 	`varlist'
	local option0 	`options'
	local ifcmd		`if'
	local incmd		`in'
	
	tempvar rbipr_touse
	qui gen		`rbipr_touse' = 1		if e(sample)
	qui replace `rbipr_touse' = 0		if `rbipr_touse' == .
	
	*! parse indepvars_en
	EndogEqMarg dep2 indep2 option2 : `"`endogenous'"'
	
	
	
	
	*!	parse rbiprobit margdec
	local 0 `origin'
	syntax [anything] [if] [in], [/*
		*/	effect(string) 			/* 	
		*/	PRedict(string) 		/*
		*/	dydx(passthru) eyex(passthru) eydx(passthru) dyex(passthru)	/*
		*/	post 					/*
		*/	Level(cilevel)			/*
		*/	*]
	
	local margopts0 `options'
	_get_diopts diopts margopts0, `margopts0'

	if "`level'" != ""{
		local level "level(`level')"
	}
	
	*! effect()
	if "`effect'" == ""{
		local effect "total"
	}
	else if !inlist("`effect'","total","direct","indirect"){
		dis in red "option effect() incorrectly specified."
		error 198
	}
	
	*! predict()
	if 	inlist("`predict'","p11","p10","p01","p00","pmarg1") | ///
		inlist("`predict'","pmarg2","pcond1","pcond2","xb1","xb2"){
			local predict "`predict'"
	}
	else if inlist("`predict'","stdp1","stdp2"){
		dis as err "{bf:predict} option {bf:`predict'} not approriate with {bf:margdec}"
		exit 322
	}
	else if "`predict'" == ""{
		local predict "p11"
	}
	else{
		dis as err "option {bf:`predict'} not allowed"
		exit 198 
	}
	
	*! parse dydx(), eyex(), dyex(), or eydx()
	if "`dydx'`eyex'`dyex'`eydx'" != ""{
		
		opts_exclusive `"`dydx' `eyex' `dyex' `eydx'"'
		
		tempname rbipr_beta
		matrix `rbipr_beta' = e(b)
		
		if "`effect'" != ""{
			local dydxeffect "dydxeffect(`effect')"
		}
		
		ParseDyDx, `dydx' `eyex' `dyex' `eydx' ///
					dep2(`dep2') matrix(`rbipr_beta') `dydxeffect'
	}
	
	*! total marginal effect	
	if "`effect'" == "total"{

		qui: `rbipr_cmdl'
		
		tempname margfailed
		if inlist("`predict'","p11","p10","p01","p00","pcond1","pcond2"){
			
			tempvar dep2orig
			qui: clonevar `dep2orig' = `dep2'
			
			if inlist("`predict'","p11","p01","pcond1","pcond2"){
			
				qui: replace `dep2' = 1
				
				cap noi margins `anything' `if' `in', /*
							*/	predict(`predict') `dydx' `post' `level' `diopts'	
				
				scalar `margfailed' = _rc
				qui: replace `dep2' = `dep2orig'
			}
			else{				
				qui: replace `dep2' = 0
				
				cap noi margins `anything' `if' `in', /*
							*/	predict(`predict') `dydx' `post' `level' `diopts'
				
				scalar `margfailed' = _rc			
				qui: replace `dep2' = `dep2orig'
			}
		}
		else{
			cap noi margins `anything' `if' `in', /*
						*/	predict(`predict') `dydx' `post' `level' `diopts'		
			scalar `margfailed' = _rc	
		}
		
		if `margfailed' == 0{
			*! adjust e() and r()
			local marg_bascmd 	= "margins"
			local marg_cmdl		= "rbiprobit margdec `0'"
				
			if "`post'" == "post"{
				MargErt ,  bascmd(`marg_bascmd') cmdl(`marg_cmdl')
			}
			MargRt , bascmd(`marg_bascmd') cmdl(`marg_cmdl')
			
		}			
		exit `margfailed'
	}
	
	
	*! clone indepvars and indepvars_en
	tempname rbipr_beta
	matrix `rbipr_beta' = e(b)
	
	*! get indepvars and indepvars_en
	ParseOrigIndep, matrix(`rbipr_beta') dep2(`dep2')
	
	forvalue x = 1(1)2{	
		local clonelist`x' = ""
		foreach varn of local indep`x'_varn{
			tempvar `varn'`x'
			qui: clonevar ``varn'`x'' = `varn'	
			local clonelist`x' "`clonelist`x'' ``varn'`x''"
		}
	}
	
	*! clone indepvars and indepvars_en wit tempvars
	ParseClonIndep, indep1(`indep1') indep2(`indep2') ///
					indep1varn(`indep1_varn') indep2varn(`indep2_varn') ///
					clone1(`clonelist1') clone2(`clonelist2')
	
	*! direct marginal effect
	if "`effect'" == "direct"{		
		
		qui: rbiprobit `dep1' = `indep1' `ifcmd' `incmd', ///
				endog(`dep2' = `indep2new', `option2') `option0'
		
		tempname margfailed
		if inlist("`predict'","p11","p10","p01","p00","pcond1","pcond2"){
			
			tempvar dep2orig
			qui: clonevar `dep2orig' = `dep2'
			
			if inlist("`predict'","p11","p01","pcond1","pcond2"){
			
				qui: replace `dep2' = 1
				
				cap noi margins `anything' `if' `in', /*
							*/	predict(`predict') `dydx' `post' `level' `diopts'
				
				scalar `margfailed' = _rc
				qui: replace `dep2' = `dep2orig'
			}
			else{
				qui: replace `dep2' = 0
				
				cap noi margins `anything' `if' `in', /*
							*/	predict(`predict') `dydx' `post' `level' `diopts'
				
				scalar `margfailed' = _rc
				qui: replace `dep2' = `dep2orig'
			}
		}
		else{
			cap noi margins `anything' `if' `in', /*
						*/	predict(`predict') `dydx' `post' `level' `diopts'			
			scalar `margfailed' = _rc	
		}
	}
	else if "`effect'" == "indirect"{
		*! indirect marginal effect
		qui: rbiprobit `dep1' = `indep1new' `ifcmd' `incmd', ///
				endog(`dep2' = `indep2', `option2') `option0'
		
		tempname margfailed
		if inlist("`predict'","p11","p10","p01","p00","pcond1","pcond2"){

			tempvar dep2orig
			qui: clonevar `dep2orig' = `dep2'
			
			if inlist("`predict'","p11","p01","pcond1","pcond2"){

				qui: replace `dep2' = 1
				
				cap noi margins `anything' `if' `in', /*
						*/	predict(`predict') `post' `dydx' `level' `diopts'
				
				scalar `margfailed' = _rc
				qui: replace `dep2' = `dep2orig'
			}
			else{
				qui: replace `dep2' = 0
				
				cap noi margins `anything' `if' `in', /*
						*/	predict(`predict') `post' `dydx' `level' `diopts'
				
				scalar `margfailed' = _rc
				qui: replace `dep2' = `dep2orig'
			}
		}
		else{
			cap noi margins `anything' `if' `in', /*
						*/	predict(`predict') `post' `dydx' `level' `diopts'
			
			scalar `margfailed' = _rc	
		}			
	}
	
	*! adjust e() and r()
	if "`effect'" == "direct" {
		local clonelist `clonelist2'
		local origlist `indep2_varn'
	}
	else if "`effect'" == "indirect"{
		local clonelist `clonelist1'
		local origlist `indep1_varn'	
	}
	
	if `margfailed' != 0{
		tempname bvec gradvec jacvec	
		mat `bvec' 		= e(b)
		mat `gradvec'	= e(gradient)
		
		MargErt, 	clonelist(`clonelist') origlist(`origlist') /*
					*/ bvec(`bvec') gradvec(`gradvec') /*
					*/ cmdl(`rbipr_cmdl')
		
		exit `margfailed'
	}				
	else{
		if "`post'" == "post"{
			tempname jacvec
			
			*!	e(cmd) and r(cmd) called margins in order marginsplot works
			local marg_bascmd	= "margins"		
			local marg_cmdl		= "rbiprobit margdec `0'"
			
			mat `jacvec' 	= e(Jacobian)

			MargErt, 	clonelist(`clonelist') origlist(`origlist') /*
						*/ jacvec(`jacvec') /*
						*/ cmdl("`marg_cmdl'") estcmdl(`rbipr_cmdl') bascmd(`marg_bascmd')

			MargRt,		clonelist(`clonelist') origlist(`origlist') /*
						*/ jacvec(`jacvec') /*
						*/ cmdl(`marg_cmdl') estcmdl(`rbipr_cmdl') bascmd(`marg_bascmd')
		}
		else{
			tempname bvec gradvec jacvec
			
			mat `bvec' 		= e(b)
			mat `gradvec'	= e(gradient)
			mat `jacvec' 	= r(Jacobian)
			
			*!	e(cmd) and r(cmd) called margins in order marginsplot works
			local marg_bascmd	= "margins"	
			local marg_cmdl		= "rbiprobit margdec `0'"
									
			MargErt, 	clonelist(`clonelist') origlist(`origlist') /*
						*/ bvec(`bvec') gradvec(`gradvec') /*
						*/ cmdl(`rbipr_cmdl')
												
			MargRt,		clonelist(`clonelist') origlist(`origlist') /*
						*/ jacvec(`jacvec') /*
						*/ cmdl(`marg_cmdl') estcmdl(`rbipr_cmdl') bascmd(`marg_bascmd')
		}
	}
end



/* PARSING */

*! parse dydx(), eyex(), dyex(), and dyex()
program define ParseDyDx, rclass

	syntax [, dydx(string) eyex(string) dyex(string) eydx(string) /*
			*/ dep2(varname) matrix(name) dydxeffect(string) ]

	return add
	
	if `"`dydx'"' != ""{
		local pfx "dydx"
	}
	else if `"`eydx'"' != ""{		
		local pfx "eydx"
	}
	else if `"`dyex'"' != ""{		
		local pfx "dyex"
	}
	else if `"`eyex'"' != ""{		
		local pfx "eyex"
	}	
	
	local lis_or 	= `"`dydx'`eyex'`dyex'`eydx'"'
	local lis_exp	= "`lis_or'"
	local lis_agg 	= ""
	
	foreach part of local lis_or{
		if "`part'" == "*"{
			local lis_agg = "`lis_agg' `part'"
			local lis_exp: subinstr local lis_exp "`part'" "", word
		}
		else if "`part'" == "_all"{
			local lis_agg = "`lis_agg' `part'"
			local lis_exp: subinstr local lis_exp "`part'" "", word
		}
		else if "`part'" == "_cons"{
			local lis_agg = "`lis_agg' `part'"
			local lis_exp: subinstr local lis_exp "`part'" "", word
		}
		else if strpos("`part'","_cont") == 1{
			local lis_agg = "`lis_agg' `part'"
			local lis_exp: subinstr local lis_exp "`part'" "", word
		}
		else if strpos("`part'","_fac") == 1{
			local lis_agg = "`lis_agg' `part'"
			local lis_exp: subinstr local lis_exp "`part'" "", word
		}
	}

	fvexpand `lis_exp'
	local lis_exp = "`r(varlist)'"
	
	fvrevar `lis_exp', list
	local indep_varn "`r(varlist)'"
	local dep2hlp = "`dep2'"
	
	local test: list indep_varn & dep2hlp
	if "`test'" != ""{
		dis as err 	"Treatment variable {bf:`dep2'} in " ///
					"{bf:dydx(), eyex(), dyex(), and eydx()} options not allowed. "
		dis as res	"Please use {help rbiprobit tmeffects} for estimation of treatment effects."
		exit 198
	}				
	
	foreach spec of local lis_exp{
		_ms_parse_parts `spec'
		if `"`r(type)'"' == "interaction"{
			dis in red "invalid {bf:dydx(), eyex(), dyex(), or eydx()} option;"
			dis in red "levels of interactions not allowed"
			error 198
		}
	}	
	
	if `"`dydx'"' != ""{
		_ms_dydx_parse `lis_agg'
		local lis_agg = "`r(varlist)'"
	}
	else if `"`eydx'"' != ""{		
		_ms_dydx_parse `lis_agg', ey
		local lis_agg = "`r(varlist)'"
	}
	else if `"`dyex'"' != ""{		
		_ms_dydx_parse `lis_agg', ex
		local lis_agg = "`r(varlist)'"
	}
	else if `"`eyex'"' != ""{		
		_ms_dydx_parse `lis_agg', ey ex
		local lis_agg = "`r(varlist)'"
	}
	
	fvexpand i.`dep2'
	local dep2hlp = "`r(varlist)'"
	local dydx: list lis_exp | lis_agg
	local dydx: list dydx - dep2hlp
	
	
	*! cleaning and binding lists
	_ms_lf_info, matrix(`matrix')
	
	local indepall = ""
	forvalue x = 1(1)`r(k_lf)'{
		local indep`x' = "`r(varlist`x')'"
		local indepall = "`indepall' `indep`x''"
	}
	
	forvalue x = 1(1)`r(k_lf)'{
		fvrevar `indep`x'', list
		local indep`x'_varn "`r(varlist)'"
		local indep`x'_varn: list uniq indep`x'_varn
	}
	fvrevar `indepall', list
	local indepall_varn "`r(varlist)'"
	local indepall_varn: list uniq indepall_varn
	
	local dydx_new = "`dydx'"
	foreach spec of local dydx{
		_ms_parse_parts `spec'
		
		local nam = "`r(name)'"
		local inlis: list indepall_varn & nam
		if "`inlis'" == ""{
			local dydx_new: subinstr local dydx_new "`spec'" "", word
		}
	}
	local dydx = "`dydx_new'"
	
	*! deletion based on effect()
	if "`dydxeffect'" == "direct"{
		local dydx_new = "`dydx'"
		
		foreach spec of local dydx{
			_ms_parse_parts `spec'
		
			local nam = "`r(name)'"
			local inlis: list indep1_varn & nam
			if "`inlis'" == ""{
				local dydx_new: subinstr local dydx_new "`spec'" "", word
			}
		}
		local dydx = "`dydx_new'"
	}
	else if "`dydxeffect'" == "indirect"{
		local dydx_new = "`dydx'"
		
		foreach spec of local dydx{
			_ms_parse_parts `spec'
		
			local nam = "`r(name)'"
			local inlis: list indep2_varn & nam
			if "`inlis'" == ""{
				local dydx_new: subinstr local dydx_new "`spec'" "", word
			}
		}
		local dydx = "`dydx_new'"	
	}	
	
	c_local dydx "`pfx'(`dydx')"
end



*! parse indepvars and indepvars_en
program define ParseOrigIndep, rclass

	syntax [, dep2(varname) matrix(name) ]

	return add
	
	_ms_lf_info, matrix(`matrix')
	
	forvalue x = 1(1)`r(k_lf)'{
		local indep`x' = "`r(varlist`x')'"
	}
	
	fvexpand i.`dep2'
	local dep2hlp = "`r(varlist)'"
	local indep1: list indep1 - dep2hlp
	
	_ms_lf_info, matrix(`matrix')
	
	forvalue x = 1(1)`r(k_lf)'{
		fvrevar `indep`x'', list
		local indep`x'_varn "`r(varlist)'"
		local indep`x'_varn: list uniq indep`x'_varn
	}
	
	c_local indep1 		`indep1'
	c_local indep2 		`indep2'
	c_local indep1_varn `indep1_varn'
	c_local indep2_varn `indep2_varn'	
end


*! parse cloned indeps with tempvars
program define ParseClonIndep, rclass

	syntax [, 	indep1(string) indep2(string) indep1varn(string) indep2varn(string) /*
			*/	clone1(string) clone2(string) ]

	return add
	
	local indep1new = "`indep1'"
	local indep2new = "`indep2'"
	
	forvalue x = 1(1)2{
		
		local varcnt : word count `indep`x'varn'
		
		forvalue y = 1(1)`varcnt'{
		
			local varnorg : word `y' of `indep`x'varn'
			local varncln : word `y' of `clone`x''
			
			foreach spec of local indep`x'{
				
				_ms_parse_parts `spec'
				
				
				if "`r(type)'" == "interaction"{
					local change = ""
					forvalue k = 1(1)`r(k_names)'{
						if "`r(name`k')'" == "`varnorg'"{
							local change = "`change'#`r(op`k')'.`varncln'"
						}
						else{
							local change = "`change'#`r(op`k')'.`r(name`k')'"
						}
					}
					
					local change: subinstr local change "#" "" 
					local indep`x'new: subinstr local indep`x'new "`spec'" "`change'", word
				}
				else if inlist("`r(type)'","variable","factor"){
					if "`r(op)'" != ""{
						if "`r(name)'" == "`varnorg'"{
							local change = "`r(op)'.`varncln'"
						}
						else{
							local change = "`r(op)'.`r(name)'"
						}
						local indep`x'new: subinstr local indep`x'new "`spec'" "`change'", word
					}
					else{
						if "`r(name)'" == "`varnorg'"{
							local change = "`varncln'"
						}
						else{
							local change = "`r(name)'"
						}
						local indep`x'new: subinstr local indep`x'new "`spec'" "`change'", word
					}
				}
			}
		}
	}
	
	c_local indep1new `indep1new'
	c_local indep2new `indep2new'
end


*! parse indepvars_en
program define EndogEqMarg
	
	args dep2 indep2 option2 colon endog_eq
	
	gettoken dep rest: endog_eq, parse(" =")
	
	c_local `dep2' `dep'
	
	*!	allow "=" after depvar_en
	gettoken equals 0 : rest, parse(" =")
	if "`equals'" != "=" { 
		local 0 `"`rest'"' 
	}		
		
	*! parse indepvars_en
	syntax [varlist(numeric default=none ts fv)], [*] 
	
	c_local `indep2' `varlist'
	c_local `option2' `options'	
end






/* STORED RESULTS */

*! adjust e()
program define MargErt, eclass

	syntax [, 	cmdl(string) bascmd(string) estcmd(string) estcmdl(string) /*
			*/	clonelist(string) origlist(string) /*
			*/	bvec(name) gradvec(name) jacvec(name) ]
	
	if "`bvec'" != ""{
		tempname b
		mat `b' = `bvec'
		local namecols: colfullnames `bvec'
		local varcnt: word count `origlist'
		
		forvalue z = 1(1)`varcnt'{
			local old: word `z' of `clonelist'
			local new: word `z' of `origlist'
				
			local namecols: subinstr local namecols "`old'" "`new'", all
		}
		mat colnames `b' = `namecols'
			
		ereturn repost b = `b', rename
	}
		
	if "`gradvec'" != ""{
		tempname grad
		mat `grad' = `gradvec'
		local namecols: colfullnames `gradvec'
		local varcnt: word count `origlist'
		
		forvalue z = 1(1)`varcnt'{
			local old: word `z' of `clonelist'
			local new: word `z' of `origlist'
			
			local namecols: subinstr local namecols "`old'" "`new'", all
		}
		mat colnames `grad' = `namecols'	
		
		ereturn matrix gradient = `grad'
	}
	
	if "`jacvec'" != ""{
		tempname jacob
		mat `jacob' = `jacvec'
		local namecols: colfullnames `jacvec'
		local varcnt: word count `origlist'
		
		forvalue z = 1(1)`varcnt'{
			local old: word `z' of `clonelist'
			local new: word `z' of `origlist'
			
			local namecols: subinstr local namecols "`old'" "`new'", all
		}
		mat colnames `jacob' = `namecols'	
		
		ereturn matrix Jacobian = `jacob'	
	}
	
	if "`estcmdl'" != ""{
		ereturn local est_cmdline 	= "`estcmdl'"
	}
	if "`cmdl'" != ""{
		ereturn local cmdline 		= "`cmdl'"
	}
	if "`bascmd'" != ""{
		ereturn local cmd 			= "`bascmd'"
	}								
end


*! adjust r()
program define MargRt, rclass
	
	syntax [, 	cmdl(string) bascmd(string) estcmd(string) estcmdl(string) /*
			*/	clonelist(string) origlist(string) /*
			*/	jacvec(name) margreturn(name) ] 
	
	return add
	
	if "`jacvec'" != ""{
		tempname jacob
		mat `jacob' = `jacvec'
		local namecols: colfullnames `jacvec'
		local varcnt: word count `origlist'
		
		forvalue z = 1(1)`varcnt'{
			local old: word `z' of `clonelist'
			local new: word `z' of `origlist'
			
			local namecols: subinstr local namecols "`old'" "`new'", all
		}
		mat colnames `jacob' = `namecols'	
		
		return matrix Jacobian = `jacob'	
	}
	
	if "`estcmdl'" != ""{
		return local est_cmdline 	= "`estcmdl'"
	}
	if "`cmdl'" != ""{
		return local cmdline 		= "`cmdl'"
	}
	if "`bascmd'" != ""{
		return local cmd 			= "`bascmd'"
	}	
end

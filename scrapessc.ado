*! version 0.1.3 10nov2026
*! Eric A. Booth
* 0.1.3 10nov2026: catalog.csv and catalog.jsonl gain a lower-case pkgname
*   column beside package (whose case is unchanged).
* 0.1.2 09nov2026: catalog takes letters() with or without quotes (quoted
*       lists such as letters("q r") were passed with doubled quotes and
*       broke the Python call); catalog notes and ignores the STB/SJ options,
*       which it never used; on Windows the default interpreter is python and
*       the shell line is wrapped so cmd.exe keeps its quotes. list and
*       install open their capture log under a private name, so they work
*       while an unnamed user log is open (was r(604)), and each STB/SJ menu
*       prints once. New option name sjissues(); the old sjiissues() still
*       works.
* 0.1.1 09nov2026: catalog expands a leading ~ in script(), python() and
*       outdir() (findfile returns ~/... under the default PLUS, which the
*       shell then passed to Python unexpanded); catalog now checks that the
*       Python scraper actually finished and errors (r(498)) when it did not,
*       instead of returning 0 with r(outdir) set
* 0.1.0 07jun2026: first release

program define scrapessc, rclass
    version 14.0

    gettoken subcmd 0 : 0, parse(" ,")
    if `"`subcmd'"' == "" {
        local subcmd "catalog"
    }
    else if `"`subcmd'"' == "," {
        local 0 `", `0'"'
        local subcmd "catalog"
    }

    local subcmd = lower(`"`subcmd'"')
    if inlist(`"`subcmd'"', "catalog", "cat", "scrape") {
        _scrapessc_catalog `0'
        return add
    }
    else if inlist(`"`subcmd'"', "hits", "count") {
        _scrapessc_hits `0'
        return add
    }
    else if inlist(`"`subcmd'"', "list", "describe") {
        _scrapessc_list `0'
        return add
    }
    else if `"`subcmd'"' == "install" {
        _scrapessc_install `0'
        return add
    }
    else {
        di as error `"unknown scrapessc subcommand: `subcmd'"'
        di as text  "valid subcommands are catalog, hits, list, and install"
        exit 198
    }
end


program define _scrapessc_catalog, rclass
    version 14.0
    syntax [, SOURCE(string) OUTdir(string) PYthon(string) ///
        SCRIPT(string) LETTERS(string) STBIssues(string) ///
        SJVolumes(string) SJIssues(string) sjiissues(string) ALL RAW WORKers(integer 16) ]

    if `"`source'"' == "" local source "ssc"
    if "`all'" != "" local source "all"
    local source = lower(`"`source'"')
    if `"`source'"' != "ssc" {
        di as error "scrapessc catalog currently supports source(ssc) only"
        di as text "use scrapessc list or scrapessc install for STB and Stata Journal software"
        exit 198
    }

    if `"`stbissues'`sjvolumes'`sjissues'`sjiissues'"' != "" {
        di as text "note: stbissues(), sjvolumes() and sjissues() apply to list and install; catalog ignores them"
    }

    local iswin = ("`c(os)'" == "Windows")
    if `"`outdir'"' == "" local outdir "`c(pwd)'/scrapessc_catalog"
    if `"`python'"' == "" {
        if `iswin' local python "python"
        else local python "python3"
    }
    if `"`script'"' == "" {
        capture findfile scrapessc.py
        if _rc {
            di as error "could not find scrapessc.py; specify script(path)"
            exit 601
        }
        local script `"`r(fn)'"'
    }

    * The shell does not expand a ~ inside double quotes, and findfile returns
    * ~/... when PLUS is the default ~/Library/.../plus/ or ~/ado/plus/
    foreach opt in script python outdir {
        _scrapessc_tilde `"``opt''"'
        local `opt' `"`r(path)'"'
    }
    capture confirm file `"`script'"'
    if _rc {
        di as error `"scrapessc.py not found at `script'"'
        exit 601
    }

    * Python's exit status does not come back through -shell-, so the
    * scraper writes this marker as its last step and Stata checks for it
    tempfile donefile
    capture erase `"`donefile'"'

    local cmd `""`python'" "`script'" catalog --source `source' --outdir "`outdir'" --workers `workers' --done-file "`donefile'""'
    if `"`letters'"' != "" local cmd `"`cmd' --letters "`letters'""'
    if "`raw'" != "" local cmd `"`cmd' --raw"'

    di as text `"running: `cmd'"'
    * cmd.exe strips the first and last quote of a line that starts with a
    * quote and holds more than two, so wrap the whole line in one more pair
    if `iswin' local cmd `""`cmd'""'
    capture noisily shell `cmd'
    if _rc {
        di as error "Python scraper returned error code " _rc
        exit _rc
    }
    capture confirm file `"`donefile'"'
    if _rc {
        di as error "the Python scraper did not finish; no catalog was written"
        di as error `"check python() (now `python') and the messages above"'
        exit 498
    }
    capture erase `"`donefile'"'

    return local outdir `"`outdir'"'
    return local source `"`source'"'
end


program define _scrapessc_tilde, rclass
    version 14.0
    args path
    if substr(`"`path'"', 1, 1) == "~" & inlist(substr(`"`path'"', 2, 1), "", "/", "\\") {
        local home : env HOME
        if "`c(os)'" == "Windows" {
            local up : env USERPROFILE
            local hd : env HOMEDRIVE
            local hp : env HOMEPATH
            if `"`up'"' != "" local home `"`up'"'
            else if `"`hd'`hp'"' != "" local home `"`hd'`hp'"'
        }
        if `"`home'"' == "" {
            di as error "cannot expand ~: HOME is not set"
            exit 601
        }
        local rest = substr(`"`path'"', 2, .)
        local path `"`home'`rest'"'
    }
    return local path `"`path'"'
end


program define _scrapessc_list, rclass
    version 14.0
    syntax [, SOURCE(string) LETTERS(string asis) STBIssues(numlist integer) ///
        SJVolumes(numlist integer) SJIssues(numlist integer) sjiissues(numlist integer) ///
        SAVing(string) ]
    if "`sjissues'" == "" local sjissues "`sjiissues'"

    _scrapessc_package_loop, mode(list) source(`"`source'"') letters(`"`letters'"') ///
        stbissues(`"`stbissues'"') sjvolumes(`"`sjvolumes'"') sjissues(`"`sjissues'"') ///
        saving(`"`saving'"')
    return add
end


program define _scrapessc_install, rclass
    version 14.0
    syntax [, SOURCE(string) LETTERS(string asis) STBIssues(numlist integer) ///
        SJVolumes(numlist integer) SJIssues(numlist integer) sjiissues(numlist integer) ///
        DRYrun CONFIRM REPLACE ALL SAVing(string) ]
    if "`sjissues'" == "" local sjissues "`sjiissues'"

    if "`confirm'" == "" {
        local dryrun "dryrun"
        di as text "install defaults to dryrun; specify confirm to install packages"
    }

    _scrapessc_package_loop, mode(install) source(`"`source'"') letters(`"`letters'"') ///
        stbissues(`"`stbissues'"') sjvolumes(`"`sjvolumes'"') sjissues(`"`sjissues'"') ///
        saving(`"`saving'"') `dryrun' `replace' `all'
    return add
end


program define _scrapessc_package_loop, rclass
    version 14.0
    syntax , MODE(string) [ SOURCE(string) LETTERS(string asis) ///
        STBIssues(numlist integer) SJVolumes(numlist integer) ///
        SJIssues(numlist integer) SAVing(string) DRYrun REPLACE ALL ]

    if `"`source'"' == "" local source "ssc"
    local source = lower(`"`source'"')
    if !inlist(`"`source'"', "ssc", "stb", "sj", "all") {
        di as error "source() must be one of ssc, stb, sj, or all"
        exit 198
    }

    tempfile pkgbase
    local pkgsmcl "`pkgbase'.smcl"
    tempname outfh
    local nfound = 0
    local nerrors = 0
    local pkglist ""

    if `"`saving'"' != "" {
        file open `outfh' using `"`saving'"', write replace
    }

    if inlist(`"`source'"', "ssc", "all") {
        if `"`letters'"' == "" local letters "`c(alpha)' _"
        foreach d of local letters {
            ssc describe `d', saving(`"`pkgsmcl'"', replace)
            scrapessc_readpkglist `"`pkgsmcl'"'
            local these `"`r(pkglist)'"'
            foreach pkg of local these {
                local ++nfound
                local pkglist `"`pkglist' `pkg'"'
                if `"`saving'"' != "" file write `outfh' "ssc,`pkg'" _n
                if `"`mode'"' == "install" {
                    _scrapessc_install_one ssc `pkg', `dryrun' `replace' `all'
                    local nerrors = `nerrors' + r(error)
                }
            }
        }
    }

    if inlist(`"`source'"', "stb", "all") {
        if `"`stbissues'"' == "" local stbissues "1/61"
        foreach issue of numlist `stbissues' {
            _scrapessc_netfrom http://www.stata.com/stb/stb`issue'/, smcl(`"`pkgsmcl'"')
            if r(rc) == 0 {
                scrapessc_readpkglist `"`pkgsmcl'"'
                local these `"`r(pkglist)'"'
                foreach pkg of local these {
                    local ++nfound
                    local pkglist `"`pkglist' `pkg'"'
                    if `"`saving'"' != "" file write `outfh' "stb`issue',`pkg'" _n
                    if `"`mode'"' == "install" {
                        _scrapessc_install_one net `pkg', from(http://www.stata.com/stb/stb`issue'/) `dryrun' `replace' `all'
                        local nerrors = `nerrors' + r(error)
                    }
                }
            }
        }
    }

    if inlist(`"`source'"', "sj", "all") {
        if `"`sjvolumes'"' == "" {
            local current_year = substr("$S_DATE", -4, 4)
            local current_vol = `current_year' - 2000
            local sjvolumes "1/`current_vol'"
        }
        if `"`sjissues'"' == "" local sjissues "1/4"
        foreach vol of numlist `sjvolumes' {
            foreach issue of numlist `sjissues' {
                local sjurl "http://www.stata-journal.com/software/sj`vol'-`issue'/"
                _scrapessc_netfrom `sjurl', smcl(`"`pkgsmcl'"')
                if r(rc) == 0 {
                    scrapessc_readpkglist `"`pkgsmcl'"'
                    local these `"`r(pkglist)'"'
                    foreach pkg of local these {
                        local ++nfound
                        local pkglist `"`pkglist' `pkg'"'
                        if `"`saving'"' != "" file write `outfh' "sj`vol'-`issue',`pkg'" _n
                        if `"`mode'"' == "install" {
                            _scrapessc_install_one net `pkg', from(`sjurl') `dryrun' `replace' `all'
                            local nerrors = `nerrors' + r(error)
                        }
                    }
                }
            }
        }
    }

    if `"`saving'"' != "" file close `outfh'
    local pkglist : list uniq pkglist
    return local pkglist `"`pkglist'"'
    return scalar n = `nfound'
    return scalar errors = `nerrors'
    di as text "packages found: " as result `nfound'
    if `"`mode'"' == "install" di as text "install errors: " as result `nerrors'
end


* Show one net-from menu and capture it to a SMCL file. The capture log has
* its own name, so an unnamed log the user already has open is not touched.
program define _scrapessc_netfrom, rclass
    version 14.0
    syntax anything(name=url), SMCL(string)
    capture log close _scrapessc
    quietly log using `"`smcl'"', replace smcl name(_scrapessc)
    capture noisily net from `url'
    local rc = _rc
    quietly log close _scrapessc
    return scalar rc = `rc'
end


program define _scrapessc_install_one, rclass
    version 14.0
    gettoken method 0 : 0
    gettoken pkg 0 : 0, parse(" ,")
    syntax [, FROM(string asis) DRYrun REPLACE ALL ]

    local opts ""
    if "`all'" != "" local opts "`opts' all"
    if "`replace'" != "" local opts "`opts' replace"
    if `"`opts'"' != "" local opts ", `opts'"

    if "`dryrun'" != "" {
        if `"`method'"' == "ssc" di as text "dryrun: ssc install `pkg'`opts'"
        else di as text `"dryrun: net install `pkg'`opts' from(`from')"'
        return scalar error = 0
        exit
    }

    if `"`method'"' == "ssc" {
        capture noisily ssc install `pkg'`opts'
    }
    else {
        capture noisily net install `pkg'`opts' from(`from')
    }
    if _rc {
        di as error "error installing `pkg' (return code " _rc ")"
        return scalar error = 1
    }
    else {
        return scalar error = 0
    }
end


program define _scrapessc_hits, rclass
    version 14.0
    syntax , [ FRom(string) TO(string) AUthor(string) CLEAR Fillin(string) ///
        GRaph PACKage(string) SAVing(string) ]

    tempvar command

    if `"`saving'"' != "" {
        _prefix_saving `saving'
        local saving `"`s(filename)'"'
        local replace `"`s(replace)'"'
        if `"`replace'"' == "" confirm new file `"`s(filename)'"'
    }

    if "`from'" == "" {
        local fromno 570
    }
    else {
        tokenize "`from'", parse("m")
        local fromno = ym(`1', `3')
    }
    if "`to'" == "" {
        local tono = mofd(td("`c(current_date)'")) - 2
    }
    else {
        tokenize "`to'", parse("m")
        local tono = ym(`1', `3')
    }
    local numdsets = 1 + `tono' - `fromno'

    if `fromno' < 570 {
        di as error "from() must be 2007m7 or later"
        exit 198
    }
    if `tono' < 570 {
        di as error "to() must be 2007m7 or later"
        exit 198
    }
    if `fromno' > `tono' {
        di as error "from() is after to()"
        exit 198
    }

    di as text "downloading `numdsets' months of SSC hits (" %tmm_CY `fromno' " to " %tmm_CY `tono' ")"
    if "`clear'" == "" {
        use "http://repec.org/docs/sschotP`fromno'.dta"
        if c(rc) != 0 {
            di as error "data in memory would be lost; specify clear"
            exit 4
        }
    }
    else {
        capture use "http://repec.org/docs/sschotP`fromno'.dta", clear
    }
    if c(rc) != 0 {
        di as error "first month of hits data not available"
        exit c(rc)
    }

    local two = `fromno' + 1
    forvalues i = `two'/`tono' {
        capture quietly append using "http://repec.org/docs/sschotP`i'.dta"
        if c(rc) != 0 di as error "warning: hits dataset " %tmm_CY `i' " not found"
    }

    capture confirm numeric variable npkghit589
    if c(rc) == 0 {
        quietly replace mo = 590 if mo == .
        quietly replace npkghit = npkghit589 if npkghit589 != .
        drop npkghit589
    }

    if `"`package'"' != "" quietly keep if package == upper(`"`package'"')
    if `"`author'"' != "" quietly keep if regexm(lower(author), lower(`"`author'"'))

    quietly count
    return scalar N = r(N)
    if r(N) == 0 di as error "warning: no matching hits records"

    quietly encode package, generate(`command')
    label var author "Author"
    label var npkghit "Number of hits"
    format npkghit %9.0f
    label var mo "Date"
    format mo %tmMon_CCYY
    label var `command' "Package"
    label var package "Package"

    if `"`fillin'"' != "" {
        quietly fillin package mo
        quietly replace npkghit = `fillin' if missing(npkghit)
        drop _fillin
    }

    quietly compress
    sort author `command' mo

    if "`graph'" != "" & "`author'" == "" & "`package'" == "" {
        di as error "graph requires author() or package() to avoid thousands of panels"
    }
    else if "`graph'" != "" & _N > 0 {
        quietly tab `command' author
        if `r(r)' == 1 & `r(c)' == 1 {
            twoway (line npkghit mo) (lowess npkghit mo), ///
                ytitle("Number of hits") ylabel(, format(%9.0f) angle(0)) xlabel(, angle(45))
        }
        else if `r(r)' == 1 & `r(c)' > 1 {
            twoway (line npkghit mo) (lowess npkghit mo), by(author, note("")) ///
                ytitle("Number of hits") ylabel(, format(%9.0f) angle(0)) xlabel(, angle(45))
        }
        else if `r(r)' > 1 & `r(c)' == 1 {
            twoway (line npkghit mo) (lowess npkghit mo), by(`command', note("")) ///
                ytitle("Number of hits") ylabel(, format(%9.0f) angle(0)) xlabel(, angle(45))
        }
        else {
            twoway (line npkghit mo) (lowess npkghit mo), by(author `command', note("")) ///
                ytitle("Number of hits") ylabel(, format(%9.0f) angle(0)) xlabel(, angle(45))
        }
    }

    if `"`saving'"' != "" {
        capture drop __*
        sort author package mo
        save `"`saving'"', `replace'
        return local saving `"`saving'"'
    }
end

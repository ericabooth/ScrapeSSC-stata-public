capture log close
log using scrapessc_demo.log, replace text

clear all
set more off

* Point Stata at this folder during local development.
adopath ++ "`c(pwd)'"

which scrapessc

* Fast Python-backed scrape of a small SSC subset.
scrapessc catalog, source(ssc) letters(a b) outdir("demo_catalog") script("scrapessc.py")

* Stata-only package list retrieval using ssc describe and SMCL parsing.
scrapessc list, source(ssc) letters(a) saving("demo_ssc_a_packages.csv")
return list

* Safe install preview. No packages are installed unless confirm is specified.
scrapessc install, source(ssc) letters(z) dryrun

* SSC hit-count retrieval, modeled on ssccount.
scrapessc hits, package(reghdfe) from(2024m1) to(2024m3) clear saving("demo_reghdfe_hits.dta", replace)
summarize npkghit

log close

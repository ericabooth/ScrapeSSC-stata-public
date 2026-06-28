{smcl}
{* *! version 0.1.0 07jun2026}{...}
{viewerjumpto "Syntax" "scrapessc##syntax"}{...}
{viewerjumpto "Description" "scrapessc##description"}{...}
{viewerjumpto "Examples" "scrapessc##examples"}{...}
{viewerjumpto "Stored results" "scrapessc##results"}{...}

{title:Title}

{pstd}
{cmd:scrapessc} {hline 2} fast SSC metadata scraping and package-list utilities for SSC, STB, and Stata Journal software


{marker syntax}{...}
{title:Syntax}

{pstd}
Fast Python-backed catalog scrape:

{phang2}
{cmd:scrapessc catalog}
[{cmd:,}
{opt source(ssc)}
{opt outdir(dirname)}
{opt python(path)}
{opt script(path)}
{opt letters(a b _)}
{opt stbissues(numlist)}
{opt sjvolumes(numlist)}
{opt sjiissues(numlist)}
{opt raw}
{opt workers(#)}
]

{pstd}
SSC hit counts over time:

{phang2}
{cmd:scrapessc hits}
{cmd:,}
[{opt from(YYYYmM)}
{opt to(YYYYmM)}
{opt author(string)}
{opt package(pkgname)}
{opt clear}
{opt fillin(#)}
{opt graph}
{opt saving(filename, replace)}
]

{pstd}
List packages available from Stata's net/ssc menus:

{phang2}
{cmd:scrapessc list}
[{cmd:,}
{opt source(ssc|stb|sj|all)}
{opt letters(a b _)}
{opt stbissues(numlist)}
{opt sjvolumes(numlist)}
{opt sjiissues(numlist)}
{opt saving(filename)}
]

{pstd}
Install packages from SSC, STB, or SJ:

{phang2}
{cmd:scrapessc install}
[{cmd:,}
{opt source(ssc|stb|sj|all)}
{opt letters(a b _)}
{opt stbissues(numlist)}
{opt sjvolumes(numlist)}
{opt sjiissues(numlist)}
{opt dryrun}
{opt confirm}
{opt all}
{opt replace}
{opt saving(filename)}
]

{pstd}
Parse a SMCL package-description file:

{phang2}
{cmd:scrapessc_readpkglist} {it:filename}

{pstd}
The helper command is installed as a separate ado file and can be used directly
after {cmd:scrapessc} is installed.


{marker description}{...}
{title:Description}

{pstd}
{cmd:scrapessc catalog} calls the companion Python program
{cmd:scrapessc.py} to scrape SSC package manifests. It reads the
alphabetized Boston College {cmd:bocode} archive directories and downloads
the linked {cmd:.pkg} manifests concurrently. The Python scraper writes
{cmd:catalog.csv}, {cmd:catalog.jsonl}, {cmd:summary.md}, and count files.

{pstd}
{cmd:scrapessc hits} is modeled on {cmd:ssccount}. It downloads the same
monthly SSC hit-count datasets used by {cmd:ssc hot}, optionally filters by
author or package, and can save or graph the resulting data.

{pstd}
{cmd:scrapessc list} and {cmd:scrapessc install} use Stata's own
{cmd:ssc describe}, {cmd:net from}, {cmd:ssc install}, and {cmd:net install}
commands. Use these Stata-side routines for STB and Stata Journal software,
because those software directories are designed to be viewed with Stata's
{cmd:net} command rather than ordinary browser scraping. These routines are
intentionally conservative. {cmd:install} defaults to a dry run unless
{cmd:confirm} is supplied, and it never uninstalls or deletes existing packages.


{marker examples}{...}
{title:Examples}

{pstd}
Scrape the full SSC catalog into a local folder:

{phang2}
{cmd:. scrapessc catalog, source(ssc) outdir("ssc_catalog")}

{pstd}
Scrape a small test subset:

{phang2}
{cmd:. scrapessc catalog, source(ssc) letters(a b) outdir("ssc_ab")}

{pstd}
Include raw SSC package manifests:

{phang2}
{cmd:. scrapessc catalog, source(ssc) outdir("ssc_catalog") raw}

{pstd}
Download monthly hit counts for one package:

{phang2}
{cmd:. scrapessc hits, package(reghdfe) from(2024m1) to(2024m12) clear saving(reghdfe_hits, replace)}

{pstd}
List SSC packages beginning with {cmd:a} and save the package names:

{phang2}
{cmd:. scrapessc list, source(ssc) letters(a) saving(ssc_a_packages.csv)}

{pstd}
Preview installation commands without installing:

{phang2}
{cmd:. scrapessc install, source(sj) sjvolumes(23) sjiissues(1) dryrun}

{pstd}
Install after explicit confirmation:

{phang2}
{cmd:. scrapessc install, source(ssc) letters(z) confirm}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:scrapessc catalog} stores:

{synoptset 20 tabbed}{...}
{synopt:{cmd:r(outdir)}}output directory{p_end}
{synopt:{cmd:r(source)}}requested source{p_end}

{pstd}
{cmd:scrapessc list} and {cmd:scrapessc install} store:

{synoptset 20 tabbed}{...}
{synopt:{cmd:r(pkglist)}}space-separated package list{p_end}
{synopt:{cmd:r(n)}}number of package records encountered{p_end}
{synopt:{cmd:r(errors)}}install errors, for {cmd:install}{p_end}

{pstd}
{cmd:scrapessc hits} stores:

{synoptset 20 tabbed}{...}
{synopt:{cmd:r(N)}}number of hit-count rows after filtering{p_end}
{synopt:{cmd:r(saving)}}saved dataset, if specified{p_end}


{title:Author}

{pstd}
Eric Booth
Sr Researcher, Texas 2036
eric.a.booth@gmail.com / eric.a.booth@gmail.com 


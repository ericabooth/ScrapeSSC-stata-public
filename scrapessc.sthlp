{smcl}
{* *! version 0.1.2 09nov2026}{...}
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
{opt raw}
{opt workers(#)}
]

{pstd}
{cmd:catalog} is also what runs when {cmd:scrapessc} is typed with no subcommand
(or with only options), so a bare {cmd:scrapessc} starts a full SSC scrape into
{cmd:scrapessc_catalog} in the working folder. The default {opt outdir()} is
{cmd:scrapessc_catalog} under the working folder.

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
{opt sjissues(numlist)}
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
{opt sjissues(numlist)}
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
{opt python()}, {opt script()}, and {opt outdir()} may be quoted, may contain
spaces, and may start with {cmd:~}, which {cmd:scrapessc} expands from your home
folder. By default the script is the {cmd:scrapessc.py} installed with the
package. If the Python program does not run or does not finish (for example, a
wrong {opt python()} path), {cmd:scrapessc catalog} stops with error 498 rather
than returning as if it had worked. {opt letters()} may be given with or
without quotes, for example {cmd:letters(a b)} or {cmd:letters("a b")}. On
Windows the default {opt python()} is {cmd:python}; elsewhere it is {cmd:python3}.

{pstd}
{cmd:catalog.csv} stores each package's full manifest, which spans several lines,
in one quoted field. Read it with {cmd:bindquote(strict)} so each package stays on
one row:

{phang2}
{cmd:. import delimited using "ssc_catalog/catalog.csv", varnames(1) bindquote(strict) encoding("utf-8") clear}

{pstd}
Package names in the catalog keep the case used in each manifest's title line
(often upper case, as in the SSC hits data), while {cmd:list} returns the lower-case
names that {cmd:ssc install} uses. Compare them with {cmd:lower()}.

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
{opt sjissues()} picks the issues within each {opt sjvolumes()} volume (default
{cmd:1/4}); the older spelling {opt sjiissues()} is still accepted. Each STB or SJ
menu is captured through a privately named log, so these routines also work while
your own log is open.


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
{cmd:. scrapessc install, source(sj) sjvolumes(23) sjissues(1) dryrun}

{pstd}
Install after explicit confirmation:

{phang2}
{cmd:. scrapessc install, source(ssc) letters(z) confirm}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:scrapessc catalog} stores:

{synoptset 20 tabbed}{...}
{synopt:{cmd:r(outdir)}}output directory (set only when the scraper finished){p_end}
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


{title:Changes}

{pstd}0.1.2 (09nov2026): {cmd:catalog} accepts quoted {opt letters()}, ignores the
STB/SJ options with a note, and on Windows defaults to {cmd:python} and keeps the
shell line's quotes. {cmd:list} and {cmd:install} work while a user log is open and
print each STB/SJ menu once. New option name {opt sjissues()}.

{pstd}0.1.1 (09nov2026): {cmd:catalog} expands a leading {cmd:~} and stops with
error 498 when the scraper does not finish.


{title:Author}

{pstd}
Eric Booth
Sr Researcher, Texas 2036
eric.a.booth@gmail.com


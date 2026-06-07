# scrapessc

`scrapessc` is a small Stata/Python package for building a local catalog of SSC package metadata and for listing/installing user-written packages from SSC, STB, and Stata Journal software archives.

#This is primarily useful for setting up an air-gapped machine that cannot download or access ado files from SSC, Stata Journal, or STB regularly.

It has two pieces:

- `scrapessc.py`: a fast, dependency-free Python scraper that retrieves browser-accessible SSC `.pkg` manifests concurrently and writes CSV/JSONL summaries.
- `scrapessc.ado`: a Stata wrapper with subcommands to run the scraper, retrieve SSC hit counts, list packages from SSC/STB/SJ menus with Stata's `net` tools, and safely dry-run or install packages.

## Files

```text
scrapessc.ado              Stata wrapper
scrapessc_readpkglist.ado  Generic SMCL package-list parser
scrapessc.py               Python scraper
scrapessc.sthlp            Stata help file
scrapessc.pkg              Stata package manifest
stata.toc                  Net-install table of contents
scrapessc_demo.do          Example Stata do-file
README.md                  GitHub README
```

## Install From GitHub

After pushing this folder to a GitHub repository, install from Stata with:

```stata
net install scrapessc, from("https://raw.githubusercontent.com/ericabooth/scrapessc/main") replace
```

For local development:

```stata
cd "/path/to/scrapessc"
adopath ++ "`c(pwd)'"
which scrapessc
help scrapessc
```

## Run The Fast Python Scraper Directly

Full SSC scrape:

```bash
python3 scrapessc.py catalog --source ssc --outdir ssc_catalog --workers 16 --raw
```

Small test scrape:

```bash
python3 scrapessc.py catalog --source ssc --letters "a b" --outdir test_ab --workers 8
```

Outputs:

```text
catalog.csv
catalog.jsonl
summary.md
source_counts.csv
topic_counts.csv
keyword_counts.csv
raw_pkg/              only when --raw is supplied
```

## Run From Stata

Full SSC catalog:

```stata
scrapessc catalog, source(ssc) outdir("ssc_catalog")
```

Small test catalog:

```stata
scrapessc catalog, source(ssc) letters(a b) outdir("test_ab")
```

If Stata cannot find the Python file, pass it explicitly:

```stata
scrapessc catalog, source(ssc) script("/path/to/scrapessc.py") outdir("ssc_catalog")
```

## SSC Hit Counts

The `hits` subcommand mirrors the core use case of `ssccount`: it downloads monthly SSC hit-count datasets, optionally filters by author/package, and can save or graph results.

```stata
scrapessc hits, package(reghdfe) from(2024m1) to(2024m12) clear ///
    saving("reghdfe_hits.dta", replace)
```

```stata
scrapessc hits, author("Correia") from(2023m1) to(2024m12) clear graph
```

## List And Install Packages

List packages from Stata's own package menus:

```stata
scrapessc list, source(ssc) letters(a) saving("ssc_a_packages.csv")
scrapessc list, source(stb) stbissues(1/5) saving("stb_1_5_packages.csv")
scrapessc list, source(sj) sjvolumes(23/25) sjiissues(1/4)
```

Preview installation commands without changing your Stata setup:

```stata
scrapessc install, source(ssc) letters(z) dryrun
```

Actually install requires explicit confirmation:

```stata
scrapessc install, source(ssc) letters(z) confirm
```

Install auxiliary files only if you explicitly want them copied to the working directory:

```stata
scrapessc install, source(sj) sjvolumes(25) sjiissues(1) confirm all
```

Overwrite existing installed packages only if you explicitly request it:

```stata
scrapessc install, source(ssc) letters(z) confirm replace
```

## Generic Package-List Utility

`scrapessc_readpkglist` parses a saved SMCL file from `ssc describe` or `net from` and returns installable package names.

```stata
ssc describe a, saving("a_desc.smcl", replace)
scrapessc_readpkglist "a_desc.smcl"
return list
display "`r(pkglist)'"
```

This generalizes the common pattern of looking for SMCL links such as:

```text
{net describe a2reg:a2reg}
@net:describe pkgname!pkgname@
```

## Speed Advantage Of Python

The slow part of a full metadata catalog is retrieving thousands of individual `.pkg` manifests. A Stata-only approach based on `copy` or `net describe` has to work mostly sequentially. The Python scraper uses concurrent HTTP requests with `--workers`, then writes structured CSV and JSONL outputs in one pass.

Benchmark on Eric Booth's Mac using StataNow/StataMP 19.5 environment and Python 3 on June 7, 2026:

```bash
/usr/bin/time -p python3 scrapessc.py catalog \
    --source ssc \
    --outdir /tmp/scrapessc_full_benchmark \
    --workers 16 \
    --progress 1000
```

Result:

```text
Found 3,937 package manifests
Processed 3,937/3,937
real 41.30
```

The Stata-side `list` and `install` tools are still useful, but they solve a different problem: they retrieve package names from Stata's package menus and optionally install packages through official `ssc install`/`net install` commands. For full SSC metadata cataloging, Python is the faster and more reproducible path.

STB and Stata Journal software directories are designed to be viewed through Stata's built-in `net` command, not ordinary browser scraping. Use `scrapessc list` and `scrapessc install` for those sources.

## Safety Notes

- `scrapessc install` defaults to dry-run unless `confirm` is specified.
- The package never uninstalls or deletes existing Stata packages.
- `replace` is opt-in.
- `all` is opt-in because auxiliary files are usually copied to the current working directory.
- Generated catalogs should not be committed unless you intentionally want a snapshot in the repository.

# scrapessc

`scrapessc` is a small Stata/Python package for building a local catalog of SSC package metadata and for listing/installing user-written packages from SSC, STB, and Stata Journal software archives.

This is primarily useful for setting up an air-gapped machine that cannot download or access ado files from SSC, Stata Journal, or STB regularly.

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

```stata
net install scrapessc, from("https://raw.githubusercontent.com/ericabooth/ScrapeSSC-stata-public/main/") replace force
discard
which scrapessc
help scrapessc
```

`scrapessc.pkg` and `stata.toc` ship with the package, so Stata's installer picks up every file in one call.

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

A leading `~` in `python()`, `script()`, or `outdir()` is expanded from your home
folder, including the `~/...` path that `findfile` reports under the default PLUS
folder. If Python does not run or does not finish, `scrapessc catalog` stops with
error 498 instead of returning as if it had worked. `letters()` may be given with
or without quotes. On Windows the default interpreter is `python` (elsewhere
`python3`). A bare `scrapessc` with no subcommand runs `catalog`, which scrapes all
of SSC into `scrapessc_catalog/` in the working folder.

`catalog.csv` keeps each multi-line manifest in one quoted field, so read it with
`bindquote(strict)`:

```stata
import delimited using "ssc_catalog/catalog.csv", varnames(1) bindquote(strict) encoding("utf-8") clear
```

Package names in the catalog keep the case of each manifest's title line (often
upper case, as in the SSC hits data); `list` returns the lower-case names that
`ssc install` uses. From 0.1.3 the catalog also has a `pkgname` column with the
lower-case name, so you can match catalog rows to `list` output or `ssc install`
without changing `package`.

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
scrapessc list, source(sj) sjvolumes(23/25) sjissues(1/4)
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
scrapessc install, source(sj) sjvolumes(25) sjissues(1) confirm all
```

`sjissues()` was spelled `sjiissues()` before 0.1.2; the old spelling still works.
`list` and `install` capture each STB/SJ menu through a privately named log, so they
also work while your own log is open.

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

## Changelog

- **0.1.2 (9 Nov 2026):** `catalog` accepts quoted `letters()` lists (they were passed with doubled quotes and broke the Python call), notes and ignores the STB/SJ options it never used, and on Windows defaults to `python` and wraps the shell line so `cmd.exe` keeps its quotes. `scrapessc.py` expands a leading `~` in `--outdir`. `list` and `install` capture menus through a privately named log, so they no longer stop with `r(604)` while an unnamed user log is open, and each STB/SJ menu prints once. New option name `sjissues()`; `sjiissues()` still works.
- **0.1.1 (9 Nov 2026):** `catalog` expands a leading `~` in `python()`, `script()`, and `outdir()`. Before, under the default macOS or Linux PLUS folder the shell passed `~/.../scrapessc.py` to Python unexpanded, Python could not open it, and the command still returned 0 with `r(outdir)` set. `catalog` now checks that the scraper finished (it writes a marker through the new `--done-file` argument) and stops with error 498 when it did not.
- **0.1.0 (7 Jun 2026):** first release.

## Author

Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com).

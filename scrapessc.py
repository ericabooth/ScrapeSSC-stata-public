#!/usr/bin/env python3
"""
scrapessc: fast package metadata scraper for SSC, STB, and Stata Journal.

This is a dependency-free Python utility intended to be called directly or
through the companion Stata command `scrapessc`.
"""

from __future__ import annotations

import argparse
import concurrent.futures as futures
import csv
import datetime as dt
import html.parser
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path


SSC_BASE_URL = "http://fmwww.bc.edu/repec/bocode/"
STB_BASE_URL = "https://www.stata.com/stb/"
SJ_BASE_URL = "https://www.stata-journal.com/software/"
USER_AGENT = "scrapessc/0.1 (+https://github.com/ericabooth/scrapessc)"
TIMEOUT = 30


TOPIC_PATTERNS = {
    "admin_official_data": r"\b(census|acs|api|fips|county|official statistics|administrative|agency|education|school|student|health|hospital|labor|employment)\b",
    "causal_evaluation": r"\b(causal|treatment effect|difference.?in.?difference|diff.?in.?diff|\bdid\b|event study|synthetic control|matching|propensity|regression discontinuity|\brd\b|instrumental|ivreg|counterfactual)\b",
    "data_quality_validation": r"\b(validate|validation|assert|quality|audit|check|codebook|metadata|duplicate|duplicates|distinct|missing|outlier|consistency|cleaning|clean)\b",
    "data_import_conversion": r"\b(import|export|convert|excel|csv|json|xml|odbc|sql|database|read|write|file|files|web|download|scrape)\b",
    "disclosure_privacy": r"\b(disclosure|confidential|privacy|suppress|suppression|small cell|anonym|synthetic data|differential privacy)\b",
    "geospatial": r"\b(spatial|geograph|geocode|gis|map|mapping|shapefile|shape file|coordinate|latitude|longitude|county|region|area|contiguity)\b",
    "graphs_tables_reporting": r"\b(graph|plot|chart|table|tabulate|report|latex|html|word|pdf|docx|putexcel|publication|visuali[sz]|dashboard)\b",
    "inequality_poverty": r"\b(poverty|inequality|gini|deprivation|welfare|income distribution|multidimensional poverty)\b",
    "missing_imputation": r"\b(missing|imputation|impute|mice|multiple imputation|nonresponse)\b",
    "reproducibility_workflow": r"\b(reproducib|dependency|dependencies|package|project|workflow|version|ado|install|github|root|path|directory)\b",
    "small_area_survey": r"\b(small area|fay.?herriot|\bsae\b|survey|sampling|weight|weights|replicate|bootstrap replicate|eblup|domain)\b",
}


class LinkParser(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.hrefs: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "a":
            return
        for key, value in attrs:
            if key.lower() == "href" and value:
                self.hrefs.append(value)


def fetch_text(url: str, retries: int = 3, quiet_404: bool = False) -> str | None:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
                data = response.read()
            return data.decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            if quiet_404 and exc.code == 404:
                return None
            last_error = exc
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = exc
        time.sleep(0.4 * (attempt + 1))
    if quiet_404:
        return None
    raise RuntimeError(f"Could not fetch {url}: {last_error}")


def links_from(url: str, quiet_404: bool = False) -> list[str]:
    html = fetch_text(url, quiet_404=quiet_404)
    if html is None:
        return []
    parser = LinkParser()
    parser.feed(html)
    return [urllib.parse.urljoin(url, href.split("?", 1)[0]) for href in parser.hrefs]


def ssc_pkg_urls(letters: list[str] | None = None) -> list[str]:
    dirs = letters or (["_"] + [chr(i) for i in range(ord("a"), ord("z") + 1)])
    urls: list[str] = []
    for dirname in dirs:
        dir_url = urllib.parse.urljoin(SSC_BASE_URL, f"{dirname}/")
        for url in links_from(dir_url):
            if url.lower().endswith(".pkg"):
                urls.append(url)
    return sorted(set(urls))


def stb_pkg_urls(issues: list[int] | None = None) -> list[str]:
    issue_nums = issues or list(range(1, 62))
    urls: list[str] = []
    for issue in issue_nums:
        dir_url = urllib.parse.urljoin(STB_BASE_URL, f"stb{issue}/")
        for url in links_from(dir_url, quiet_404=True):
            if url.lower().endswith(".pkg"):
                urls.append(url)
    return sorted(set(urls))


def sj_pkg_urls(volumes: list[int] | None = None, issues: list[int] | None = None) -> list[str]:
    current_volume = dt.date.today().year - 2000
    volume_nums = volumes or list(range(1, current_volume + 1))
    issue_nums = issues or [1, 2, 3, 4]
    urls: list[str] = []
    for volume in volume_nums:
        for issue in issue_nums:
            dir_url = urllib.parse.urljoin(SJ_BASE_URL, f"sj{volume}-{issue}/")
            for url in links_from(dir_url, quiet_404=True):
                if url.lower().endswith(".pkg"):
                    urls.append(url)
    return sorted(set(urls))


def parse_pkg(text: str, url: str, source: str) -> dict[str, object]:
    d_lines: list[str] = []
    keywords: list[str] = []
    authors: list[str] = []
    support: list[str] = []
    files: list[str] = []
    requires: list[str] = []
    distribution_date = ""

    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("d "):
            content = stripped[2:].strip()
            low = content.lower()
            if content.startswith("KW:"):
                keywords.append(content[3:].strip())
            elif low.startswith("requires:"):
                requires.append(content.split(":", 1)[1].strip())
            elif low.startswith("distribution-date:"):
                distribution_date = content.split(":", 1)[1].strip()
            elif low.startswith("author:"):
                authors.append(content.split(":", 1)[1].strip())
            elif low.startswith("support:"):
                support.append(content.split(":", 1)[1].strip())
            else:
                d_lines.append(content)
        elif stripped.startswith("f "):
            files.append(stripped[2:].strip())

    parsed = urllib.parse.urlparse(url)
    pkg_file = Path(parsed.path).name
    archive_dir = Path(parsed.path).parent.name
    package = Path(parsed.path).stem
    first_nonempty = next((line for line in d_lines if line.strip()), "")
    title = first_nonempty
    match = re.match(r"^'([^']+)':\s*(.*)$", first_nonempty)
    if match:
        package = match.group(1).strip()
        title = match.group(2).strip()

    description = " ".join(line.strip() for line in d_lines[1:] if line.strip())
    description = re.sub(r"\s+", " ", description).strip()
    manifest = "\n".join(d_lines).strip()
    haystack = " ".join([package, title, description, " ".join(keywords)]).lower()
    topics = [
        topic
        for topic, pattern in TOPIC_PATTERNS.items()
        if re.search(pattern, haystack, flags=re.IGNORECASE)
    ]

    return {
        "source": source,
        "package": package,
        "pkg_file": pkg_file,
        "archive_dir": archive_dir,
        "title": title,
        "description": description,
        "keywords": "; ".join(dict.fromkeys(k for k in keywords if k)),
        "authors": "; ".join(a for a in authors if a),
        "support": "; ".join(s for s in support if s),
        "requires": "; ".join(r for r in requires if r),
        "distribution_date": distribution_date,
        "files": "; ".join(files),
        "file_count": len(files),
        "topics": "; ".join(topics),
        "url": url,
        "manifest": manifest,
    }


def fetch_parse_pkg(task: tuple[str, str, Path | None]) -> tuple[dict[str, object] | None, str | None]:
    url, source, raw_dir = task
    try:
        text = fetch_text(url)
        if text is None:
            return None, f"{url}\tmissing"
        record = parse_pkg(text, url, source)
        if raw_dir:
            raw_name = f"{source}__{record['archive_dir']}__{record['pkg_file']}"
            (raw_dir / raw_name).write_text(text, encoding="utf-8")
        return record, None
    except Exception as exc:  # noqa: BLE001
        return None, f"{url}\t{exc}"


def write_csv(records: list[dict[str, object]], path: Path) -> None:
    fields = [
        "source",
        "package",
        "pkg_file",
        "archive_dir",
        "title",
        "description",
        "keywords",
        "authors",
        "requires",
        "distribution_date",
        "file_count",
        "topics",
        "url",
        "files",
        "support",
        "manifest",
    ]
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)


def write_jsonl(records: list[dict[str, object]], path: Path) -> None:
    with path.open("w", encoding="utf-8") as f:
        for record in records:
            f.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")


def write_summary(records: list[dict[str, object]], errors: list[str], outdir: Path, elapsed: float) -> None:
    source_counts = Counter(str(r["source"]) for r in records)
    topic_counts: Counter[str] = Counter()
    keyword_counts: Counter[str] = Counter()
    for record in records:
        for topic in str(record["topics"]).split("; "):
            if topic:
                topic_counts[topic] += 1
        for keyword in str(record["keywords"]).split("; "):
            if keyword:
                keyword_counts[keyword.lower()] += 1

    def write_counts(path: Path, header: str, counts: Counter[str]) -> None:
        with path.open("w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow([header, "count"])
            writer.writerows(counts.most_common())

    write_counts(outdir / "source_counts.csv", "source", source_counts)
    write_counts(outdir / "topic_counts.csv", "topic", topic_counts)
    write_counts(outdir / "keyword_counts.csv", "keyword", keyword_counts)
    if errors:
        (outdir / "errors.txt").write_text("\n".join(errors) + "\n", encoding="utf-8")

    lines = [
        "# scrapessc catalog summary",
        "",
        f"Retrieved UTC: {dt.datetime.now(dt.timezone.utc).isoformat()}",
        f"Elapsed seconds: {elapsed:.2f}",
        f"Package manifests parsed: {len(records):,}",
        f"Fetch/parse errors: {len(errors):,}",
        "",
        "## Sources",
        "",
    ]
    for source, count in source_counts.most_common():
        lines.append(f"- {source}: {count:,}")
    lines += ["", "## Topics", ""]
    for topic, count in topic_counts.most_common():
        lines.append(f"- {topic}: {count:,}")
    lines += ["", "## Top keywords", ""]
    for keyword, count in keyword_counts.most_common(40):
        lines.append(f"- {keyword}: {count:,}")
    outdir.joinpath("summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_csv_ints(value: str | None) -> list[int] | None:
    if not value:
        return None
    vals: list[int] = []
    for item in re.split(r"[,\s]+", value.strip()):
        if item:
            vals.append(int(item))
    return vals


def parse_letters(value: str | None) -> list[str] | None:
    if not value:
        return None
    letters = []
    for item in re.split(r"[,\s]+", value.strip().lower()):
        if item:
            if item != "_" and not re.fullmatch(r"[a-z]", item):
                raise ValueError(f"Invalid SSC letter/directory: {item}")
            letters.append(item)
    return letters


def run_catalog(args: argparse.Namespace) -> int:
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    raw_dir = outdir / "raw_pkg" if args.raw else None
    if raw_dir:
        raw_dir.mkdir(parents=True, exist_ok=True)

    selected_sources = ["ssc", "stb", "sj"] if args.source == "all" else [args.source]
    url_tasks: list[tuple[str, str, Path | None]] = []

    if "ssc" in selected_sources:
        for url in ssc_pkg_urls(parse_letters(args.letters)):
            url_tasks.append((url, "ssc", raw_dir))
    if "stb" in selected_sources:
        print(
            "Warning: STB software directories are intended for Stata's net command; "
            "browser scraping may find zero manifests.",
            file=sys.stderr,
        )
        for url in stb_pkg_urls(parse_csv_ints(args.stb_issues)):
            url_tasks.append((url, "stb", raw_dir))
    if "sj" in selected_sources:
        print(
            "Warning: Stata Journal software directories are intended for Stata's net command; "
            "browser scraping may find zero manifests.",
            file=sys.stderr,
        )
        for url in sj_pkg_urls(parse_csv_ints(args.sj_volumes), parse_csv_ints(args.sj_issues)):
            url_tasks.append((url, "sj", raw_dir))

    start = time.perf_counter()
    print(f"Found {len(url_tasks):,} package manifests", file=sys.stderr)
    records: list[dict[str, object]] = []
    errors: list[str] = []
    with futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        future_map = {executor.submit(fetch_parse_pkg, task): task for task in url_tasks}
        for i, future in enumerate(futures.as_completed(future_map), start=1):
            record, error = future.result()
            if record:
                records.append(record)
            if error:
                errors.append(error)
            if args.progress and (i % args.progress == 0 or i == len(url_tasks)):
                print(f"Processed {i:,}/{len(url_tasks):,}", file=sys.stderr)

    records.sort(key=lambda r: (str(r["source"]), str(r["package"]).lower(), str(r["url"])))
    write_csv(records, outdir / "catalog.csv")
    write_jsonl(records, outdir / "catalog.jsonl")
    write_summary(records, errors, outdir, time.perf_counter() - start)
    print(f"Wrote catalog outputs to {outdir}", file=sys.stderr)
    return 0 if not errors else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scrapessc",
        description="Scrape browser-accessible Stata package manifests. SSC is fully supported; use Stata net commands for STB/SJ.",
    )
    sub = parser.add_subparsers(dest="command")
    catalog = sub.add_parser("catalog", help="scrape package manifests")
    catalog.add_argument("--source", choices=["ssc", "stb", "sj", "all"], default="ssc")
    catalog.add_argument("--outdir", default="scrapessc_catalog")
    catalog.add_argument("--letters", help="SSC directories to scrape, e.g. 'a b c _'")
    catalog.add_argument("--stb-issues", help="STB issues to scrape, e.g. '1 2 3'")
    catalog.add_argument("--sj-volumes", help="SJ volumes to scrape, e.g. '20 21 22'")
    catalog.add_argument("--sj-issues", help="SJ issue numbers to scrape, e.g. '1 2 3 4'")
    catalog.add_argument("--workers", type=int, default=16)
    catalog.add_argument("--progress", type=int, default=250)
    catalog.add_argument("--raw", action="store_true", help="save raw .pkg manifests")
    catalog.set_defaults(func=run_catalog)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not hasattr(args, "func"):
        args = parser.parse_args(["catalog", *(argv or [])])
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())

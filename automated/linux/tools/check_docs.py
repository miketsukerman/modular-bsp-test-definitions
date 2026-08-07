#!/usr/bin/env python3
"""
check_docs.py
Advantech BSP QA – repository ↔ documentation consistency checker

Verifies that the documentation under docs/ and the module tables in README.md
stay in sync with the modules under automated/linux/, so documentation cannot
silently drift away from the tests.

Reported findings:
  * modules without a suite document, and suite documents without a module
  * modules missing from the README.md and docs/tests/README.md suite tables
  * suite tables naming definition files that do not exist
  * LAVA definition names in the tables that differ from the YAML `metadata.name`
  * module YAML files whose `run` steps do not point at their own directory
  * test-case IDs documented in a suite document but not emitted by its
    scripts, and emitted IDs that the suite document does not describe
  * the docs/tests/README.md test-case ID index disagreeing with the emitted
    IDs or attributing an ID to the wrong suite
  * relative Markdown links pointing at missing files or headings

Usage:
    python3 check_docs.py [--repo-root <dir>] [--quiet]

Exit status is non-zero when any finding is reported.

Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
"""

import argparse
import os
import re
import sys
from typing import Dict, List, Set, Tuple

from check_requirements import base_id, emitted_ids, expand_enumerated

# Directories under automated/linux/ that are not test modules.
NON_MODULE_DIRS = ("lib", "utils", "tools")

# Table row: | cell | cell | … |
ROW_RE = re.compile(r"^\|(?P<body>.*)\|\s*$")

# Inline code span, e.g. `adv-gpio`.
CODE_RE = re.compile(r"`([^`]+)`")

# Requirement ID inside a code span, e.g. `L-GPIO-DEV-${label}`.
ID_CODE_RE = re.compile(r"^L-[A-Z0-9]")

# Bare instance placeholder used in the suite documents, e.g. "-dev{N}", which
# stands for the same instance suffix the scripts append via a shell variable.
PLACEHOLDER_RE = re.compile(r"(?<!\$)\{[A-Za-z]\w*\}")

# Markdown link with a relative target, e.g. [gpio](../../automated/linux/…).
LINK_RE = re.compile(r"\[[^\]]*\]\((?P<target>[^)\s]+)\)")

# ATX heading, e.g. "## Test cases".
HEADING_RE = re.compile(r"^(?P<level>#{1,6})\s+(?P<title>.+?)\s*#*$")

# Fenced code block delimiter.
FENCE_RE = re.compile(r"^\s*(```|~~~)")

# Characters dropped by GitHub when deriving a heading anchor.
ANCHOR_STRIP_RE = re.compile(r"[^\w\- ]")


def read_lines(path: str) -> List[str]:
    with open(path, encoding="utf-8") as fh:
        return fh.read().splitlines()


def strip_code_fences(lines: List[str]) -> List[str]:
    """Drop fenced code blocks, whose contents are examples, not statements."""
    out: List[str] = []
    fence = None
    for line in lines:
        m = FENCE_RE.match(line)
        if m:
            if fence is None:
                fence = m.group(1)
                continue
            if m.group(1) == fence:
                fence = None
                continue
        if fence is None:
            out.append(line)
    return out


def table_rows(lines: List[str]) -> List[List[str]]:
    """Return the cells of every Markdown table row, separators excluded."""
    rows = []
    for line in lines:
        m = ROW_RE.match(line)
        if not m:
            continue
        cells = [c.strip() for c in m.group("body").split("|")]
        if all(set(c) <= set("-: ") and c for c in cells):
            continue
        rows.append(cells)
    return rows


def section(lines: List[str], title: str) -> List[str]:
    """Return the lines of the section with the given heading title."""
    out: List[str] = []
    level = None
    for line in lines:
        m = HEADING_RE.match(line)
        if m:
            if level is None:
                if m.group("title").strip() == title:
                    level = len(m.group("level"))
                continue
            if len(m.group("level")) <= level:
                break
            continue
        if level is not None:
            out.append(line)
    return out


def anchor(title: str) -> str:
    """Derive the GitHub heading anchor for a heading title."""
    text = CODE_RE.sub(r"\1", title)
    text = LINK_RE.sub("", text)
    text = re.sub(r"\[([^\]]*)\]", r"\1", text)
    text = ANCHOR_STRIP_RE.sub("", text.lower())
    return text.replace(" ", "-")


def anchors(path: str) -> Set[str]:
    out: Set[str] = set()
    for line in strip_code_fences(read_lines(path)):
        m = HEADING_RE.match(line)
        if m:
            out.add(anchor(m.group("title")))
    return out


def modules(repo_root: str) -> List[str]:
    linux_dir = os.path.join(repo_root, "automated", "linux")
    return sorted(
        name for name in os.listdir(linux_dir)
        if name not in NON_MODULE_DIRS
        and os.path.isdir(os.path.join(linux_dir, name))
    )


def documented_ids(path: str) -> Set[str]:
    """Base test-case IDs listed in the `Test cases` table of a suite doc."""
    lines = strip_code_fences(read_lines(path))
    found: Set[str] = set()
    for cells in table_rows(section(lines, "Test cases")):
        if not cells:
            continue
        m = CODE_RE.search(cells[0])
        if not m or not ID_CODE_RE.match(m.group(1)):
            continue
        raw = PLACEHOLDER_RE.sub("${n}", m.group(1))
        for ident in expand_enumerated(raw):
            found.add(base_id(ident))
    return found


def index_ids(path: str) -> Dict[str, Set[str]]:
    """Base test-case ID → suites, from the ID index of docs/tests/README.md."""
    lines = strip_code_fences(read_lines(path))
    result: Dict[str, Set[str]] = {}
    for cells in table_rows(section(lines, "Test-case ID index")):
        if len(cells) < 2:
            continue
        m = CODE_RE.search(cells[0])
        link = LINK_RE.search(cells[1])
        if not m or not ID_CODE_RE.match(m.group(1)) or not link:
            continue
        suite = os.path.splitext(os.path.basename(link.group("target")))[0]
        for ident in expand_enumerated(m.group(1)):
            result.setdefault(base_id(ident), set()).add(suite)
    return result


def suite_table(path: str, name_column: bool) -> Dict[str, List[str]]:
    """
    Suite → cells of its row in a module table.

    The suite is taken from the first cell's Markdown link target, so both the
    README.md table (linking to docs/tests/<suite>.md) and the docs/tests
    index (linking to <suite>.md) are understood.
    """
    lines = strip_code_fences(read_lines(path))
    result: Dict[str, List[str]] = {}
    for cells in table_rows(lines):
        if len(cells) < (3 if name_column else 2):
            continue
        link = LINK_RE.search(cells[0])
        if not link or not link.group("target").endswith(".md"):
            continue
        suite = os.path.splitext(os.path.basename(link.group("target")))[0]
        if suite == "README":
            continue
        result[suite] = cells
    return result


def yaml_metadata_name(path: str) -> str:
    for line in read_lines(path):
        m = re.match(r"^\s{2}name:\s*(?P<name>\S+)", line)
        if m:
            return m.group("name")
    return ""


def check_modules_and_docs(repo_root: str, findings: List[str]) -> None:
    docs_dir = os.path.join(repo_root, "docs", "tests")
    mods = modules(repo_root)
    docs = sorted(
        os.path.splitext(name)[0] for name in os.listdir(docs_dir)
        if name.endswith(".md") and name != "README.md"
    )

    for module in mods:
        if module not in docs:
            findings.append(f"module without a suite document: {module}")
    for doc in docs:
        if doc not in mods:
            findings.append(f"suite document without a module: {doc}.md")

    for module in mods:
        module_dir = os.path.join(repo_root, "automated", "linux", module)
        names = sorted(os.listdir(module_dir))
        for yaml_name in [n for n in names if n.endswith(".yaml")]:
            stem = os.path.splitext(yaml_name)[0]
            if f"{stem}.sh" not in names:
                findings.append(
                    f"{module}/{yaml_name} has no matching {stem}.sh script")
            steps = "\n".join(read_lines(os.path.join(module_dir, yaml_name)))
            expected = f"cd ./automated/linux/{module}"
            if expected not in steps:
                findings.append(
                    f"{module}/{yaml_name} run steps do not "
                    f"'{expected}'")
        for sh_name in [n for n in names if n.endswith(".sh")]:
            stem = os.path.splitext(sh_name)[0]
            if f"{stem}.yaml" not in names:
                findings.append(
                    f"{module}/{sh_name} has no matching {stem}.yaml "
                    f"definition")


def check_suite_tables(repo_root: str, findings: List[str]) -> None:
    mods = set(modules(repo_root))
    tables = {
        "README.md": (os.path.join(repo_root, "README.md"), False),
        "docs/tests/README.md": (
            os.path.join(repo_root, "docs", "tests", "README.md"), True),
    }
    for label, (path, name_column) in tables.items():
        rows = suite_table(path, name_column)
        for module in sorted(mods - set(rows)):
            findings.append(f"{label}: module table is missing {module}")
        for suite in sorted(set(rows) - mods):
            findings.append(f"{label}: module table lists unknown suite {suite}")

        for suite, cells in sorted(rows.items()):
            if suite not in mods:
                continue
            module_dir = os.path.join(repo_root, "automated", "linux", suite)
            actual_yaml = {n for n in os.listdir(module_dir)
                           if n.endswith(".yaml")}
            files_cell = cells[2] if name_column else cells[1]
            listed_yaml = {c for c in CODE_RE.findall(files_cell)
                           if c.endswith(".yaml")}
            for name in sorted(listed_yaml - actual_yaml):
                findings.append(
                    f"{label}: {suite} row lists non-existent {name}")
            for name in sorted(actual_yaml - listed_yaml):
                findings.append(
                    f"{label}: {suite} row does not list {name}")
            if not name_column:
                continue
            listed_names = set(CODE_RE.findall(cells[1]))
            actual_names = {yaml_metadata_name(os.path.join(module_dir, n))
                            for n in actual_yaml}
            for name in sorted(listed_names ^ actual_names):
                findings.append(
                    f"{label}: {suite} row LAVA names disagree with the YAML "
                    f"metadata ({name})")


def check_test_case_docs(repo_root: str, findings: List[str]) -> None:
    emitted = emitted_ids(repo_root)
    per_module: Dict[str, Set[str]] = {}
    for ident, mods in emitted.items():
        for module in mods:
            per_module.setdefault(module, set()).add(ident)

    docs_dir = os.path.join(repo_root, "docs", "tests")
    for module in modules(repo_root):
        doc = os.path.join(docs_dir, f"{module}.md")
        if not os.path.isfile(doc):
            continue
        documented = documented_ids(doc)
        emitted_here = per_module.get(module, set())
        for ident in sorted(emitted_here - documented):
            findings.append(
                f"docs/tests/{module}.md: no test-case row for {ident}")
        for ident in sorted(documented - emitted_here):
            findings.append(
                f"docs/tests/{module}.md: documents {ident}, which "
                f"{module} does not emit")

    index = index_ids(os.path.join(docs_dir, "README.md"))
    for ident in sorted(set(emitted) - set(index)):
        findings.append(
            f"docs/tests/README.md: test-case ID index is missing {ident}")
    for ident in sorted(set(index) - set(emitted)):
        findings.append(
            f"docs/tests/README.md: test-case ID index lists {ident}, which "
            f"no module emits")
    for ident in sorted(set(index) & set(emitted)):
        for suite in sorted(index[ident] - emitted[ident]):
            findings.append(
                f"docs/tests/README.md: test-case ID index attributes {ident} "
                f"to {suite}, which does not emit it")


def markdown_files(repo_root: str) -> List[str]:
    out = []
    for dirpath, dirnames, filenames in os.walk(repo_root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in sorted(filenames):
            if name.endswith(".md"):
                out.append(os.path.join(dirpath, name))
    return sorted(out)


def check_links(repo_root: str, findings: List[str]) -> None:
    anchor_cache: Dict[str, Set[str]] = {}
    for path in markdown_files(repo_root):
        rel = os.path.relpath(path, repo_root)
        for line in strip_code_fences(read_lines(path)):
            for m in LINK_RE.finditer(line):
                target = m.group("target")
                if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target) \
                        or target.startswith("#"):
                    continue
                file_part, _, fragment = target.partition("#")
                if not file_part:
                    continue
                dest = os.path.normpath(
                    os.path.join(os.path.dirname(path), file_part))
                if not os.path.exists(dest):
                    findings.append(f"{rel}: broken link to {target}")
                    continue
                if not fragment or not dest.endswith(".md"):
                    continue
                if dest not in anchor_cache:
                    anchor_cache[dest] = anchors(dest)
                if fragment.lower() not in anchor_cache[dest]:
                    findings.append(f"{rel}: link to missing heading {target}")


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_root = os.path.abspath(os.path.join(here, "..", "..", ".."))

    ap = argparse.ArgumentParser(
        description="Check the documentation against the repository contents.")
    ap.add_argument("--repo-root", default=default_root,
                    help="Repository root (default: derived from script path)")
    ap.add_argument("--quiet", action="store_true",
                    help="Only print findings")
    args = ap.parse_args()

    findings: List[str] = []
    check_modules_and_docs(args.repo_root, findings)
    check_suite_tables(args.repo_root, findings)
    check_test_case_docs(args.repo_root, findings)
    check_links(args.repo_root, findings)

    for finding in findings:
        print(finding)
    if not args.quiet:
        print(f"{len(findings)} finding(s).")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())

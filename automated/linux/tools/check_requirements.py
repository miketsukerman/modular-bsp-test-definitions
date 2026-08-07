#!/usr/bin/env python3
"""
check_requirements.py
Advantech BSP QA – requirements.yaml ↔ test-script synchronisation checker

Statically extracts every requirement ID the module scripts can emit and
compares it against the catalogue in requirements.yaml, so that the catalogue
cannot silently drift away from the tests.

Reported findings:
  * emitted requirement IDs with no catalogue entry
  * catalogue entries that match no emitted requirement ID
  * duplicate catalogue keys
  * prefix-shadowing catalogue keys (resolved by longest match – correct but
    fragile, so authors are told about them)

Usage:
    python3 check_requirements.py [--repo-root <dir>] [--catalog <path>]
                                  [--allow-missing ID[,ID…]] [--quiet]

Exit status is non-zero when any finding (other than an informational prefix
warning) is reported.

Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
"""

import argparse
import os
import re
import sys
from typing import Dict, List, Set, Tuple

# ─── Requirement-ID extraction ────────────────────────────────────────────────

# Result reporters defined in lib/adv-test-lib.sh whose first argument is a
# requirement ID.
REPORTERS = ("report_pass", "report_fail", "report_skip", "report_unknown",
             "report_metric", "run_adv_test")

# report_pass "L-FOO"     /  report_pass "${req_dev}"  /  report_pass "$req_dev"
REPORT_RE = re.compile(
    r"\b(?:" + "|".join(REPORTERS) + r")\s+\"?(?P<arg>\$\{?\w+\}?|L-[^\"\s]+)\"?"
)

# req_dev="L-I2C-DEV-i2c${n}"
ASSIGN_RE = re.compile(r"^\s*(?P<var>\w+)=\"?(?P<val>L-[^\"\s]+)\"?", re.MULTILINE)

# Any requirement-ID literal, including the ones handed to helper functions
# such as chk_bus() or file_read_test() rather than to a reporter directly.
LITERAL_RE = re.compile(r"\"(?P<val>L-[^\"\s]*)\"")

# Comment line – requirement IDs quoted in prose are not emitted.
COMMENT_RE = re.compile(r"^\s*#")

# Shell variables used as an instance suffix that is *not* separated from the
# base ID by one of the separators the consumer accepts (- _ . : /), so the
# catalogue needs one key per expansion.
ENUMERATED_VARS = {"proto": ("4", "6")}

VAR_RE = re.compile(r"\$\{?(\w+)\}?")

# Trailing instance label, e.g. "-i2c0", "-rtc0", "-disk" (after the shell
# variable that followed it was stripped).
INSTANCE_TAIL_RE = re.compile(r"-[a-z][a-z0-9]*$")
LITERAL_INSTANCE_TAIL_RE = re.compile(r"-[a-z]+[0-9]+$")

# Characters the consumer accepts between a catalogue key and its instance
# suffix when doing longest-prefix resolution.
SEPARATORS = "-_.:/"


def lava_id(raw: str) -> str:
    """Apply the same sanitisation as lava_id() in lib/adv-test-lib.sh."""
    return raw.replace("\u00b7", "-").replace(":", "-")


def expand_enumerated(ident: str) -> List[str]:
    """Expand known enumerated shell variables, e.g. ${proto} → 4 and 6."""
    out = [ident]
    for var, values in ENUMERATED_VARS.items():
        expanded: List[str] = []
        for item in out:
            for pattern in ("${%s}" % var, "$%s" % var):
                if pattern in item:
                    expanded.extend(item.replace(pattern, v) for v in values)
                    break
            else:
                expanded.append(item)
        out = expanded
    return out


def base_id(raw: str) -> str:
    """
    Reduce an emitted requirement ID to its instance-free base form, which is
    what the catalogue is keyed by.

        L-I2C-DEV-i2c${n}     → L-I2C-DEV
        L-CPU-C-STATES-${k}   → L-CPU-C-STATES
        L-SUSPEND-WAKEUP-F-rtc0 → L-SUSPEND-WAKEUP-F
        L-CAN-LOOPBACK:F-can${n} → L-CAN-LOOPBACK-F
    """
    ident = lava_id(raw)
    stripped_var = False
    while True:
        new = re.sub(r"\$\{?\w+\}?$", "", ident)
        if new == ident:
            break
        ident = new
        stripped_var = True
    if stripped_var:
        ident = ident.rstrip("-_.")
        ident = INSTANCE_TAIL_RE.sub("", ident)
    else:
        ident = LITERAL_INSTANCE_TAIL_RE.sub("", ident)
    return ident


def scan_script(path: str) -> Set[str]:
    """Return every requirement ID a single module script can emit."""
    with open(path, encoding="utf-8") as fh:
        lines = [line for line in fh if not COMMENT_RE.match(line)]
    text = "".join(lines)

    # A variable may be assigned several requirement IDs (different branches),
    # so keep every value while resolving reporter arguments to the last one.
    assignments: Dict[str, str] = {}
    found: Set[str] = set()
    for m in ASSIGN_RE.finditer(text):
        assignments[m.group("var")] = m.group("val")
        found.add(m.group("val"))

    for m in REPORT_RE.finditer(text):
        arg = m.group("arg")
        if arg.startswith("L-"):
            found.add(arg)
            continue
        var = VAR_RE.match(arg)
        if var and var.group(1) in assignments:
            found.add(assignments[var.group(1)])

    # Requirement IDs passed to helpers such as chk_bus() or file_read_test()
    # never appear at a reporter call site, so take every literal as well.
    found.update(m.group("val") for m in LITERAL_RE.finditer(text))
    return found


def emitted_ids(repo_root: str) -> Dict[str, Set[str]]:
    """Map base requirement ID → set of module names that can emit it."""
    linux_dir = os.path.join(repo_root, "automated", "linux")
    result: Dict[str, Set[str]] = {}
    for dirpath, _dirnames, filenames in sorted(os.walk(linux_dir)):
        module = os.path.basename(dirpath)
        if module in ("lib", "utils", "tools"):
            continue
        for name in sorted(filenames):
            if not name.endswith(".sh"):
                continue
            for raw in sorted(scan_script(os.path.join(dirpath, name))):
                for ident in expand_enumerated(raw):
                    result.setdefault(base_id(ident), set()).add(module)
    return result


# ─── Catalogue loading ────────────────────────────────────────────────────────

# A deliberately small YAML reader is used so the checker keeps the same
# dependency-free profile as conf_to_yaml.py. PyYAML is preferred when present.
KEY_RE = re.compile(r"^(?P<indent> *)(?P<key>[^\s#:][^:]*):(?P<rest>.*)$")


def load_catalog_keys(path: str) -> Tuple[List[str], List[str]]:
    """
    Return (keys in file order, duplicate keys).

    Accepts the wrapped form (top-level ``requirements:``/``test_cases:``/
    ``testcases:`` mapping) and a bare id → entry mapping.
    """
    try:
        import yaml  # type: ignore
    except ImportError:
        return _load_catalog_keys_fallback(path)

    with open(path, encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected a mapping at the top level")
    for wrapper in ("requirements", "test_cases", "testcases"):
        if isinstance(data.get(wrapper), dict):
            data = data[wrapper]
            break
    keys = [str(k) for k in data]
    # PyYAML silently collapses duplicate keys, so detect them textually.
    _, duplicates = _load_catalog_keys_fallback(path)
    return keys, duplicates


def _load_catalog_keys_fallback(path: str) -> Tuple[List[str], List[str]]:
    """Textual scan for the requirement keys, used without PyYAML."""
    keys: List[str] = []
    duplicates: List[str] = []
    seen: Set[str] = set()
    wrapper_indent = None

    with open(path, encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            m = KEY_RE.match(line)
            if not m:
                continue
            indent = len(m.group("indent"))
            key = m.group("key").strip().strip("'\"")
            rest = m.group("rest").strip()
            if wrapper_indent is None:
                if indent == 0 and key in ("requirements", "test_cases",
                                           "testcases") and not rest:
                    # The wrapper's own indentation is 0; the requirement keys
                    # below it set wrapper_indent on the next iteration.
                    continue
                if indent == 0 and not key.startswith("L-"):
                    continue
                wrapper_indent = indent
            if indent != wrapper_indent:
                continue
            if key in seen:
                duplicates.append(key)
            else:
                seen.add(key)
                keys.append(key)
    return keys, duplicates


# ─── Checks ───────────────────────────────────────────────────────────────────

def resolves(ident: str, keys: Set[str]) -> bool:
    """Mirror RequirementCatalog.resolve(): exact, then longest prefix."""
    if ident in keys:
        return True
    return any(
        ident.startswith(key) and ident[len(key)] in SEPARATORS for key in keys
    )


def prefix_hazards(keys: List[str]) -> List[Tuple[str, str]]:
    """Catalogue keys where one shadows another under prefix resolution."""
    hazards = []
    for short in keys:
        for long in keys:
            if short == long or not long.startswith(short):
                continue
            if long[len(short)] in SEPARATORS:
                hazards.append((short, long))
    return sorted(hazards)


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_root = os.path.abspath(os.path.join(here, "..", "..", ".."))

    ap = argparse.ArgumentParser(
        description="Check requirements.yaml against the emitted test-case IDs."
    )
    ap.add_argument("--repo-root", default=default_root,
                    help="Repository root (default: derived from script path)")
    ap.add_argument("--catalog", default=None,
                    help="Catalogue path (default: <repo-root>/requirements.yaml)")
    ap.add_argument("--allow-missing", default="",
                    help="Comma-separated base IDs allowed to have no entry yet")
    ap.add_argument("--quiet", action="store_true",
                    help="Only print findings")
    args = ap.parse_args()

    catalog_path = args.catalog or os.path.join(args.repo_root,
                                                "requirements.yaml")
    if not os.path.isfile(catalog_path):
        print(f"ERROR: catalogue not found: {catalog_path}", file=sys.stderr)
        return 2

    try:
        keys, duplicates = load_catalog_keys(catalog_path)
    except Exception as exc:  # noqa: BLE001 – report and fail, never traceback
        print(f"ERROR: cannot read {catalog_path}: {exc}", file=sys.stderr)
        return 2

    allow = {i.strip() for i in args.allow_missing.split(",") if i.strip()}
    emitted = emitted_ids(args.repo_root)
    key_set = set(keys)

    missing = sorted(i for i in emitted if not resolves(i, key_set)
                     and i not in allow)
    orphans = sorted(k for k in key_set
                     if not any(resolves(i, {k}) for i in emitted))
    hazards = prefix_hazards(keys)

    failures = 0

    if missing:
        failures += len(missing)
        print("Emitted requirement IDs with no catalogue entry:")
        for ident in missing:
            print(f"  {ident}  ({', '.join(sorted(emitted[ident]))})")

    if orphans:
        failures += len(orphans)
        print("Catalogue entries matching no emitted requirement ID:")
        for key in orphans:
            print(f"  {key}")

    if duplicates:
        failures += len(duplicates)
        print("Duplicate catalogue keys:")
        for key in sorted(set(duplicates)):
            print(f"  {key}")

    stale_allow = sorted(i for i in allow
                         if i not in emitted or resolves(i, key_set))
    if stale_allow:
        failures += len(stale_allow)
        print("Allow-list entries that are no longer needed:")
        for ident in stale_allow:
            print(f"  {ident}")

    if hazards and not args.quiet:
        print("Prefix-shadowing catalogue keys (resolved by longest match):")
        for short, long in hazards:
            print(f"  {short} ⊂ {long}")

    if not args.quiet:
        print(f"{len(emitted)} emitted requirement IDs, "
              f"{len(keys)} catalogue entries, {failures} finding(s).")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

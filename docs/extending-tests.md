# Extending the test suite

This guide explains how to add a **new test module** (or a new test case to an
existing module) to the modular BSP test suite. It assumes you've read the
[README](../README.md) for the overall layout and [`test-reference.md`](test-reference.md)
for the parameter/test-case conventions.

Every module is the same shape — a **YAML** test definition plus a **shell**
script — so adding one is mostly a matter of following the existing pattern.

## LAVA test-definition specification

Each module YAML conforms to the **Lava-Test Test Definition 1.0** format. Keep
these upstream references handy while authoring:

* [Writing a LAVA test definition](https://docs.lavasoftware.org/lava/writing-tests.html)
  – the `metadata` / `params` / `run` structure used by every module here.
* [Test definition reference](https://docs.lavasoftware.org/lava/test-definitions.html)
  – the full list of supported keys (`metadata`, `params`, `install`, `run`,
  `parse`, …) and their semantics.
* [The `test` action](https://docs.lavasoftware.org/lava/actions-test.html)
  – how LAVA loads a definition in a job and overrides `params` via
  `parameters:` (see [`lava-usage.md`](lava-usage.md)).
* [Custom result handling / `lava-test-case`](https://docs.lavasoftware.org/lava/results.html)
  – the signals this suite emits indirectly through
  [`utils/send-to-lava.sh`](../automated/linux/utils/send-to-lava.sh).

> This suite uses **only** the `metadata`, `params`, and `run` keys. Results are
> produced by the module script writing `output/result.txt` and converting it
> with `send-to-lava.sh`, rather than by LAVA's built-in `parse:` pattern.

## Anatomy of a module

A module named `foo` lives in `automated/linux/foo/` and contains two files:

```
automated/linux/foo/
├── foo.yaml   # LAVA test definition: metadata, params, run.steps
└── foo.sh     # checks; sources ../lib/adv-test-lib.sh, writes output/result.txt
```

The YAML's `run.steps` always follow the same three-step pattern: `cd` into the
module dir, run the script, hand `result.txt` to `send-to-lava.sh`.

## Step 1 — Create the module directory and YAML

Create `automated/linux/foo/foo.yaml`. Start from this template (modelled on
[`i2c.yaml`](../automated/linux/i2c/i2c.yaml)):

```yaml
metadata:
  format: Lava-Test Test Definition 1.0
  name: adv-foo                       # convention: adv-<module>
  description: >
    Advantech BSP QA – Foo subsystem checks: verifies that each configured
    foo device exists and behaves as expected.
  maintainer:
    - qa@advantech.com
  os:
    - yocto
    - debian
  scope:
    - functional
  devices:
    - all

params:
  FOO_COUNT: "1"            # Number of foo instances to check
  FOO0_DEV: "/dev/foo0"    # Device node for instance 0
  FOO0_EXPECTED: ""         # Expected value (empty -> that sub-check is skipped)
  # FOO1_DEV, FOO1_EXPECTED, … for additional instances

run:
  steps:
    - cd ./automated/linux/foo
    - bash foo.sh
    - bash ../utils/send-to-lava.sh ./output/result.txt
```

Guidelines for `params`:

* Provide every key the script reads, with a **safe default** (LAVA exports each
  key as an environment variable; a missing key becomes an empty string).
* Use a `*_COUNT` key plus numbered blocks (`FOO0_*`, `FOO1_*`, …) for repeatable
  hardware instances — the script iterates `0..COUNT-1`. See the `instances_of`
  pattern used by the `i2c`, `eth`, `disk`, etc. modules.
* Quote any value that isn't a plain integer (strings with spaces, `|`, or empty
  strings), e.g. `FOO0_EXPECTED: ""`.

## Step 2 — Write the module script

Create `automated/linux/foo/foo.sh`. The boilerplate that every module shares:

```bash
#!/bin/bash
# shellcheck disable=SC2154
#
# foo.sh — Advantech BSP QA – Foo subsystem checks
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${FOO_COUNT:=1}"

n=0
while [ "${n}" -lt "${FOO_COUNT}" ]; do
    eval "dev=\${FOO${n}_DEV}"
    eval "expected=\${FOO${n}_EXPECTED}"

    req_dev="L-FOO-DEV-foo${n}"

    # Presence/permission check
    if chk_rw_cdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Optional sub-check, only when a value was supplied
    if [ -n "${expected}" ]; then
        req_val="L-FOO-VALUE-foo${n}"
        if some_check "${dev}" "${expected}"; then
            report_pass "${req_val}"
        else
            report_fail "${req_val}"
        fi
    fi

    n=$((n + 1))
done
```

Use the helpers from [`lib/adv-test-lib.sh`](../automated/linux/lib/adv-test-lib.sh)
rather than re-implementing them — they keep result formatting and ID
sanitisation consistent. The most-used ones:

| Helper | Purpose |
|--------|---------|
| `create_out_dir` | Create `output/` for `result.txt`. **Call once at the top.** |
| `report_pass/fail/skip/unknown <id>` | Emit a single result line. |
| `report_metric <id> <result> <meas> [units]` | Emit a measurement result line. |
| `run_adv_test <id> <cmd…>` | Run a command; pass on exit 0, fail otherwise. |
| `chk_cmd <cmd>` | True if a command exists in `PATH`. |
| `chk_rw_cdev / chk_rw_bdev <path>` | Char/block device exists and is R/W. |
| `chk_bus pci\|soc …` | Verify a bus controller exists. |

### Test-case ID conventions

Follow the same rules the rest of the suite uses (see the
[README](../README.md#test-case-id-conventions)):

* Prefix IDs with `L-` then the subsystem, e.g. `L-FOO-DEV`.
* Append a per-instance label after a `·` (U+00B7 middle dot), e.g.
  `L-FOO-DEV·foo0`. In practice most scripts build the label inline
  (`L-FOO-DEV-foo${n}`) which is already LAVA-safe.
* Add a trailing **`:F`** for a **functional** test (real hardware behaviour:
  loopback, throughput, suspend). Functional tests should **`report_skip`** when
  their prerequisites (hardware, parameters, tools) are absent — never fail.
* `lava_id()` (called inside the `report_*` helpers) sanitises `·` and `:` to
  `-`, so `L-FOO-LOOPBACK:F·foo0` is reported as `L-FOO-LOOPBACK-F-foo0`. Use the
  sanitised form when documenting IDs.

### Choosing pass / fail / skip

* **pass / fail** – the check ran and gave a definitive answer.
* **skip** – the check could not run because a prerequisite was missing
  (required tool not installed, no loopback cable, parameter empty). Prefer skip
  over fail for "not applicable on this board".
* **unknown** – the check ran but the result is indeterminate.

## Step 3 — Make the script executable and verify locally

`send-to-lava.sh` degrades gracefully when the `lava-test-case` binary is absent
(it prints `LAVA_SIGNAL_*` lines instead), so you can run a module outside LAVA:

```sh
cd automated/linux/foo
FOO_COUNT=1 FOO0_DEV=/dev/foo0 FOO0_EXPECTED=bar bash foo.sh
cat output/result.txt

# Optional: confirm the result lines translate to LAVA signals
bash ../utils/send-to-lava.sh ./output/result.txt
```

Lint the script before committing (the suite is shellcheck-clean):

```sh
shellcheck automated/linux/foo/foo.sh
```

## Step 4 — Wire the module into the board-parameter generator (optional)

If the new module's parameters should be auto-generated from a board `.conf`
file, register it in
[`tools/conf_to_yaml.py`](../automated/linux/tools/conf_to_yaml.py):

1. Add a `conv_foo(...)` converter function (alongside `conv_i2c`,
   `conv_thermal`, …) that maps the relevant `CFGA_FOO` array into the module's
   param keys.
2. Read the array near the other `arrays.get("CFGA_…")` calls:
   `foo = arrays.get("CFGA_FOO", {})`.
3. Add an entry to the `modules = { … }` dict: `"foo": conv_foo(foo),`.

Then `python3 tools/conf_to_yaml.py board.conf --out-dir /tmp/yaml` will emit
`/tmp/yaml/foo/params.yaml`. Modules that aren't board-parameterised (or that
you fill in by hand) can skip this step.

## Step 5 — Document the module

Keep the docs in sync so others can use your module:

1. **`README.md`** – add a row to the *Test modules at a glance* table and, if it
   creates a new directory, the *Repository layout* tree.
2. **`docs/test-reference.md`** – add a `## foo (adv-foo)` section listing every
   `params` key (default + meaning) and every test-case ID the module emits.
3. **`docs/lava-usage.md`** – optionally add a `test` definition entry to the job
   example if the module is part of a standard run.

## Adding a test case to an existing module

To extend a module instead of creating one:

1. Add any new `params` keys (with defaults) to the module's `*.yaml`.
2. Emit the new check(s) from the module's `*.sh` using a fresh `L-…` ID and the
   `report_*` helpers.
3. Update the module's section in [`test-reference.md`](test-reference.md) with
   the new parameters and test-case IDs.

## Disruptive tests get their own job

If a test changes the board's power state (suspend, reboot) it must **not** share
a job with other tests. Split it into its own module/job pair — see how
[`rtc-suspend`](../automated/linux/rtc) and
[`watchdog-reboot`](../automated/linux/watchdog) are separated, and the
[disruptive-tests note in `lava-usage.md`](lava-usage.md#disruptive-tests-belong-in-their-own-jobs).

## Checklist

- [ ] `automated/linux/foo/foo.yaml` with `metadata`, `params` (defaults), and the standard 3-step `run`.
- [ ] `automated/linux/foo/foo.sh` sourcing `adv-test-lib.sh`, using `report_*` helpers and `L-` IDs.
- [ ] Functional (`:F`) checks degrade to `report_skip` when prerequisites are absent.
- [ ] Runs locally and `output/result.txt` looks correct; `shellcheck` is clean.
- [ ] (Optional) Registered in `tools/conf_to_yaml.py`.
- [ ] README table, `test-reference.md` section, and (if relevant) `lava-usage.md` updated.

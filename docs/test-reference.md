# Test Reference

> **This page has moved.** The per-module reference now lives in
> [`docs/tests/`](tests/README.md) — one document per test suite.

Each suite document covers:

* **Scope** – what the module checks and what it deliberately doesn't.
* **Prerequisites** – extra hardware, target-side tools, root requirements.
* **Parameters** – every YAML `params` key, its default, and meaning.
* **Test cases** – the LAVA test-case IDs the module emits (sanitised form, see
  the [README](../README.md#test-case-id-conventions)) with their pass, fail
  and skip criteria.
* **Running locally**, **verbose logging** and **troubleshooting** notes.

Start at the [test suite index](tests/README.md). It also contains a global
[test-case ID index](tests/README.md#test-case-id-index) for looking up a
failing LAVA result.

To add a new module or test case, see
[`extending-tests.md`](extending-tests.md).

## Conventions used in the suite documents

* `N` / `${n}` – a zero-based instance index (`i2c0`, `eth1`, …). Modules with a
  `*_COUNT` parameter iterate from `0` to `COUNT-1`; each numbered parameter
  block (`*0_*`, `*1_*`, …) configures one instance.
* `:F` test cases are **functional** and degrade to **skip** when their
  hardware prerequisites or parameters are missing.
* `${label}` in an ID is the per-instance device label (e.g. `eth0`).

### Common parameter (all modules)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `VERBOSE` | `"0"` | Set to `"1"` to enable verbose diagnostic logging. When enabled, each test case writes an `output/<id>.log` file containing `INFO:` banners, raw command output, and a `RESULT:` summary line. These log files are picked up by `send-to-lava.sh` and surfaced inside LAVA results. |

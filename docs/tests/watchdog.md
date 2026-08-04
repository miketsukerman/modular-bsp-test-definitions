# watchdog (`adv-watchdog` + `adv-watchdog-reboot`)

Watchdog checks: non-disruptive device-node and daemon checks from
`watchdog.yaml`, plus a separate disruptive reboot test from
`watchdog-reboot.yaml` that deliberately lets the hardware watchdog reset the
board.

* **Definition:** [`automated/linux/watchdog/watchdog.yaml`](../../automated/linux/watchdog/watchdog.yaml)
* **Script:** [`automated/linux/watchdog/watchdog.sh`](../../automated/linux/watchdog/watchdog.sh)
* **Definition:** [`automated/linux/watchdog/watchdog-reboot.yaml`](../../automated/linux/watchdog/watchdog-reboot.yaml)
* **Script:** [`automated/linux/watchdog/watchdog-reboot.sh`](../../automated/linux/watchdog/watchdog-reboot.sh)

## Scope

### `watchdog.yaml` / `watchdog.sh` (`adv-watchdog`)

**Covered**

* `/dev/watchdogN` exists and is a readable/writable character device.
* A process whose name matches `watchdog` is running.

**Not covered**

* Watchdog timeout programming, keepalive operation, pretimeout interrupts, or
  actual reset behaviour.

### `watchdog-reboot.yaml` / `watchdog-reboot.sh` (`adv-watchdog-reboot`)

**Covered**

* The configured watchdog device exists.
* The script records a pass result, opens the watchdog, withholds the magic close
  keepalive sequence, sleeps for the configured timeout, and expects the board to
  reboot before the sleep returns.

**Not covered**

* Verifying the reboot after the board comes back; LAVA job recovery and result
  collection must prove that externally.
* Running safely alongside other test suites. This test is disruptive.

`watchdog-reboot` is disruptive because it reboots the board. It must run as its
own LAVA job; see [Disruptive tests belong in their own jobs](../lava-usage.md#disruptive-tests-belong-in-their-own-jobs).

## Prerequisites

* **Hardware:** a hardware watchdog exposed as `/dev/watchdogN`. The reboot test
  must be allowed to reset the board and LAVA must be able to log in again after
  the reset.
* **Target tools:** `pgrep`, `sleep`, and `truncate`; standard shell utilities
  only for device checks.
* **Root:** required when the watchdog character device is not accessible to the
  test user. The reboot test needs permission to open the watchdog device for
  writing.

## Parameters

### `watchdog.yaml` / `watchdog.sh` (`adv-watchdog`)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WATCHDOG_COUNT` | `"1"` | Number of watchdog devices to iterate over (`watchdog0` … `watchdog<COUNT-1>`) |
| `WATCHDOG{N}_DEV` | `/dev/watchdog0` | Character device node for watchdog `N` |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

### `watchdog-reboot.yaml` / `watchdog-reboot.sh` (`adv-watchdog-reboot`)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WATCHDOG_DEV` | `/dev/watchdog0` | Character device node to open for the reboot test |
| `WATCHDOG_TIMEOUT_S` | `"30"` | Seconds to sleep while waiting for the watchdog reset |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

## Test cases

IDs are shown in sanitised (LAVA) form.

### `watchdog.yaml` / `watchdog.sh` (`adv-watchdog`)

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-WATCHDOG-DEV-watchdog{N}` | | Device node exists and is a read/writable char device | Node missing or not R/W | — |
| `L-WATCHDOG-SERVICE` | | `pgrep watchdog` finds a running watchdog daemon | No matching watchdog daemon is running | — |

### `watchdog-reboot.yaml` / `watchdog-reboot.sh` (`adv-watchdog-reboot`)

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-WATCHDOG-REBOOT-F` | ✓ | Result is written before opening the watchdog; the intended successful outcome is that the board reboots before the timeout sleep returns | If the script reaches the end of the sleep without a reboot, it truncates the result file and reports fail | `skip` when `WATCHDOG_DEV` does not exist |

## Running locally

Non-disruptive checks:

```sh
cd automated/linux/watchdog
WATCHDOG_COUNT=1 \
WATCHDOG0_DEV=/dev/watchdog0 \
bash watchdog.sh
cat output/result.txt
```

Disruptive reboot check (run only when an immediate board reboot is acceptable):

```sh
cd automated/linux/watchdog
WATCHDOG_DEV=/dev/watchdog0 \
WATCHDOG_TIMEOUT_S=30 \
bash watchdog-reboot.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1`, `watchdog.sh` writes `output/<test-case-id>.log` for
`L-WATCHDOG-DEV-*` and `L-WATCHDOG-SERVICE`. `watchdog-reboot.sh` writes a log
for `L-WATCHDOG-REBOOT-F` before triggering the watchdog. LAVA surfaces these
logs alongside the test result when they survive result collection.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-WATCHDOG-DEV-*` fails | Wrong watchdog node, watchdog driver missing, or insufficient permissions |
| `L-WATCHDOG-SERVICE` fails | Watchdog daemon is not installed/running, or its process name does not match `watchdog` |
| `L-WATCHDOG-REBOOT-F` skips | `WATCHDOG_DEV` does not exist |
| `L-WATCHDOG-REBOOT-F` fails | Watchdog did not fire within `WATCHDOG_TIMEOUT_S`, magic-close behaviour disabled reset, or another daemon kept feeding the watchdog |
| LAVA job loses the board during reboot | The reboot test was not isolated in its own job or the job lacks recovery/auto-login handling |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_WATCHDOG` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

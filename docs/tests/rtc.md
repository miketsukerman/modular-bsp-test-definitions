# rtc (`adv-rtc` + `adv-rtc-suspend`)

RTC checks cover the non-disruptive `rtc.yaml` suite and the separate
`rtc-suspend.yaml` wakeup suite. `rtc-suspend` is disruptive because it suspends
the board, so it must run as its own LAVA job; see
[Disruptive tests belong in their own jobs](../lava-usage.md#disruptive-tests-belong-in-their-own-jobs).

* **Definition:** [`automated/linux/rtc/rtc.yaml`](../../automated/linux/rtc/rtc.yaml)
* **Script:** [`automated/linux/rtc/rtc.sh`](../../automated/linux/rtc/rtc.sh)
* **Definition:** [`automated/linux/rtc/rtc-suspend.yaml`](../../automated/linux/rtc/rtc-suspend.yaml)
* **Script:** [`automated/linux/rtc/rtc-suspend.sh`](../../automated/linux/rtc/rtc-suspend.sh)

## Scope

**Covered**

* **rtc.yaml / rtc.sh:** default `/dev/rtc` access; each configured RTC device
  node; `hwclock --get`; `hwclock --set` round-trip to the read time; and the
  `/sys/class/rtc/<iface>/device/power/wakeup` value.
* **rtc-suspend.yaml / rtc-suspend.sh:** `rtcwake` using the configured RTC,
  sleep state, and wake delay, with the elapsed resume time reported in seconds.

**Not covered**

* Long-term RTC drift, backup-battery retention, alarm persistence across power
  loss, or wall-clock correctness beyond a get/set round-trip.
* Running suspend/wakeup alongside other tests; the suspend suite intentionally
  belongs in a separate LAVA job.

## Prerequisites

* **Hardware:** at least one RTC device. For `rtc-suspend`, the selected RTC must
  be able to wake the board from the configured sleep state.
* **Target tools:** `hwclock` for `rtc.sh`; `rtcwake` for `rtc-suspend.sh`;
  standard `date` is used for parsing and elapsed-time measurement.
* **Root:** required. Reading/writing RTC character devices, setting hardware
  time, and suspending the board normally require root privileges.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RTC_COUNT` | `"1"` | `rtc.yaml`: number of RTC devices to iterate over (`rtc0` … `rtc<COUNT-1>`) |
| `RTC{N}_DEV` | `/dev/rtc0` | `rtc.yaml`: character device node for RTC `N` |
| `RTC{N}_WAKEUP` | `enabled` | `rtc.yaml`: expected `/sys/class/rtc/<iface>/device/power/wakeup` value; missing sysfs file is treated as `disabled` |
| `RTC_DEV` | `/dev/rtc0` | `rtc-suspend.yaml`: RTC device passed to `rtcwake -d` |
| `SLEEP_STATE` | `mem` | `rtc-suspend.yaml`: sleep state passed to `rtcwake -m`, for example `mem`, `freeze`, or `standby` |
| `WAKE_SLEEP_TIME_S` | `"5"` | `rtc-suspend.yaml`: seconds passed to `rtcwake -s` and minimum expected elapsed time |
| `VERBOSE` | `"0"` | Both suites: `"1"` enables per-test-case diagnostic logs |

The board converter also emits `RTC_SUSPEND_*` values from `CFGA_RTC`; map them
to `RTC_DEV`, `SLEEP_STATE`, and `WAKE_SLEEP_TIME_S` when running
`rtc-suspend.yaml`.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `rtc<N>` for `rtc.yaml`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-RTC-DEFAULT` | | `/dev/rtc` exists and is a readable/writable character device | Node missing, wrong type, or not R/W | Always emitted by `rtc.sh` |
| `L-RTC-DEV-${label}` | | `RTC{N}_DEV` exists and is a readable/writable character device | Node missing, wrong type, or not R/W; remaining checks for this RTC are abandoned | Always emitted for each `RTC_COUNT` instance |
| `L-RTC-GET-F-${label}` | ✓ | `hwclock --rtc <dev> --get` returns non-empty output | `hwclock --get` returns empty output; set and wakeup checks for this RTC are abandoned | Only emitted after `L-RTC-DEV-${label}` passes |
| `L-RTC-SET-F-${label}` | ✓ | `hwclock --rtc <dev> --set --date <read-time>` succeeds | `hwclock --set` exits non-zero | Only emitted after `L-RTC-GET-F-${label}` passes |
| `L-RTC-WAKEUP-${label}` | | Wakeup sysfs value equals `RTC{N}_WAKEUP` | Value differs; a missing sysfs file is compared as `disabled` | Only emitted after `L-RTC-GET-F-${label}` passes |
| `L-SUSPEND-WAKEUP-F-rtc0` | ✓ | `rtcwake` exits `0` and elapsed time is at least `WAKE_SLEEP_TIME_S`; reported as a measurement in `s` | `rtcwake` fails, or elapsed time is shorter than `WAKE_SLEEP_TIME_S` | `skip` when `RTC_DEV` does not exist |

## Running locally

```sh
cd automated/linux/rtc
RTC_COUNT=1 \
RTC0_DEV=/dev/rtc0 \
RTC0_WAKEUP=enabled \
bash rtc.sh
cat output/result.txt

RTC_DEV=/dev/rtc0 \
SLEEP_STATE=mem \
WAKE_SLEEP_TIME_S=5 \
bash rtc-suspend.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1`, `rtc.sh` writes `output/<test-case-id>.log` for emitted
`L-RTC-DEFAULT`, `L-RTC-DEV-*`, `L-RTC-GET-F-*`, `L-RTC-SET-F-*`, and
`L-RTC-WAKEUP-*` checks. `rtc-suspend.sh` writes a log for
`L-SUSPEND-WAKEUP-F-rtc0`, including the measured elapsed seconds when the
metric path is used. Each log ends in a `RESULT:` line, and LAVA surfaces these
logs alongside the test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-RTC-DEFAULT` fails | `/dev/rtc` symlink missing, RTC driver not loaded, or insufficient permissions |
| `L-RTC-DEV-*` fails | Wrong `RTC{N}_DEV`, device node missing, or not running as root |
| `L-RTC-GET-F-*` fails | `hwclock` missing, RTC not readable, or invalid device path |
| `L-RTC-SET-F-*` fails | `hwclock --set` denied by permissions, RTC is read-only, or the read time could not be parsed by `date` |
| `L-RTC-WAKEUP-*` fails | Expected wakeup value does not match sysfs; use `disabled` when the wakeup file is absent |
| `L-SUSPEND-WAKEUP-F-rtc0` is skipped | `RTC_DEV` for `rtc-suspend.sh` does not exist |
| `L-SUSPEND-WAKEUP-F-rtc0` fails | `rtcwake` failed, the sleep state is unsupported, wakeup is disabled, or the board resumed too early |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_RTC` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

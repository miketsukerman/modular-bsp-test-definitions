# cpu (`adv-cpu`)

CPU checks: processor count, configured C-state names, cpufreq minimum and
maximum frequencies, cpufreq governor availability and setting, and advertised
system power-suspension states.

* **Definition:** [`automated/linux/cpu/cpu.yaml`](../../automated/linux/cpu/cpu.yaml)
* **Script:** [`automated/linux/cpu/cpu.sh`](../../automated/linux/cpu/cpu.sh)

## Scope

**Covered**

* `nproc` output matches one of the configured acceptable CPU counts.
* For present CPUs in the matched variant, configured C-state names are found in
  `/sys/devices/system/cpu/cpuN/cpuidle/state*/name`.
* cpufreq `scaling_min_freq` and `scaling_max_freq` match configured values.
* Configured governors are present in `scaling_available_governors`; when
  possible, `cpufreq-set` is used to set each governor and restore the previous
  one.
* Configured suspension state names are present in `/sys/power/state`.

**Not covered**

* CPU model matching; `CPU_MODEL` is defined in YAML but not consumed by
  `cpu.sh` (the context suite checks CPU model).
* Actual suspend/resume entry; the script only reads `/sys/power/state`.
* CPU load, performance, thermal throttling, or power measurements.

## Prerequisites

* **Hardware:** configured CPUs and cpufreq/cpuidle sysfs entries must be
  exposed by the kernel for the optional per-core checks.
* **Target tools:** `nproc`, `grep`, `cat`, and `xargs`; `cpufreq-set` is only
  needed for the governor-setting functional check.
* **Root:** not required for read-only checks. The governor-setting functional
  check usually requires root or equivalent permission; otherwise it fails.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CPU_MODEL` | `"Cortex-A35"` | Expected CPU model string; defined by YAML but currently not consumed by `cpu.sh` |
| `CPU_NPROC` | `"4"` | Space-separated acceptable CPU counts, for example `2 4`; empty = CPU-count and per-core checks not emitted |
| `CPU_CSTATES` | `""` | Space-separated expected C-state names; empty = no C-state checks for present CPUs |
| `CPU_SCALING_MIN` | `"0"` | Expected `scaling_min_freq` in kHz; `0` = check not emitted |
| `CPU_SCALING_MAX` | `"0"` | Expected `scaling_max_freq` in kHz; `0` = check not emitted |
| `CPU_SCALING_GOVERNORS` | `""` | Space-separated governor names to verify and optionally set |
| `CPU_SUSPENSION_STATES` | `""` | Space-separated `/sys/power/state` values to verify |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

For variant lists such as `CPU_NPROC="2 4"`, the script checks CPUs in the
matched count and emits skip results for higher-index CPUs up to the maximum
configured count.

## Test cases

IDs are shown in sanitised (LAVA) form. `${k}` is `cpu<N>`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-CPU-NPROC` | | `nproc` equals one entry in `CPU_NPROC` | `nproc` does not match any configured count | Not emitted when `CPU_NPROC` is empty |
| `L-CPU-C-STATES-${k}` | | A configured C-state name appears under `cpuN/cpuidle/state*/name` | The C-state name is not found | Skip for CPUs above the matched variant count; not emitted for present CPUs when `CPU_CSTATES` is empty |
| `L-CPU-FREQ-SCALING-MIN-${k}` | | `scaling_min_freq` equals `CPU_SCALING_MIN` | Value differs or is unreadable | Skip for CPUs above the matched variant count; not emitted when `CPU_SCALING_MIN` is `0` or cpufreq is absent |
| `L-CPU-FREQ-SCALING-MAX-${k}` | | `scaling_max_freq` equals `CPU_SCALING_MAX` | Value differs or is unreadable | Skip for CPUs above the matched variant count; not emitted when `CPU_SCALING_MAX` is `0` or cpufreq is absent |
| `L-CPU-SCALING-GOVERNOR-${k}` | | Governor appears in `scaling_available_governors` | Governor is not available | Skip for CPUs above the matched variant count; not emitted when `CPU_SCALING_GOVERNORS` is empty or cpufreq is absent |
| `L-CPU-SCALING-GOVERNOR-SET-F-${k}` | ✓ | `cpufreq-set` successfully sets the governor with configured min/max values | `cpufreq-set` runs and fails | Skip when `cpufreq-set` is missing, min/max are not both greater than `0`, governor availability failed, or the CPU is above the matched variant count |
| `L-CPU-POWER-STATE-SUSPENSION` | | Configured state appears in `/sys/power/state` | State is missing | Not emitted when `CPU_SUSPENSION_STATES` is empty |

C-state, governor, governor-set, and suspension checks are emitted once for each
configured value, so the same test-case ID may appear multiple times.

## Running locally

```sh
cd automated/linux/cpu
CPU_NPROC="4" \
CPU_CSTATES="WFI" \
CPU_SCALING_MIN=400000 \
CPU_SCALING_MAX=1800000 \
CPU_SCALING_GOVERNORS="performance powersave" \
CPU_SUSPENSION_STATES="freeze mem" \
bash cpu.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for emitted
checks that call `verbose_log`, recording expected values, found values, and
cpufreq governor-setting attempts. LAVA surfaces these logs alongside the test
result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-CPU-NPROC` fails | `CPU_NPROC` does not include the actual `nproc` value for this board variant |
| Per-core checks skip for higher CPUs | Variant list includes a larger CPU count than the currently booted variant |
| Frequency checks are missing | cpufreq sysfs is absent, or `CPU_SCALING_MIN`/`CPU_SCALING_MAX` are `0` |
| `L-CPU-SCALING-GOVERNOR-*` fails | Governor is not advertised by the cpufreq driver |
| `L-CPU-SCALING-GOVERNOR-SET-F-*` skips or fails | `cpufreq-set` is missing, min/max are not configured, or privileges/policy prevent changing governors |
| `L-CPU-POWER-STATE-SUSPENSION` fails | The configured state is not advertised in `/sys/power/state` |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_CPU` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

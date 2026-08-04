# gpio (`adv-gpio`)

GPIO checks: `gpiochip` device node presence, sysfs chip entry and controller
label, line count, and per-pin direction, input read, output set high/low and
interrupt edge configuration.

* **Definition:** [`automated/linux/gpio/gpio.yaml`](../../automated/linux/gpio/gpio.yaml)
* **Script:** [`automated/linux/gpio/gpio.sh`](../../automated/linux/gpio/gpio.sh)

## Scope

**Covered**

* `/dev/gpiochipN` exists and is readable/writable.
* `/sys/class/gpio/<chip>` entry exists and its `label` matches the expected
  controller.
* Line count reported by `gpioinfo` matches the expected value.
* For each configured pin: direction, input value read-back, output write of
  `0` and `1`, and the presence/value of the sysfs `edge` file for IRQ pins.

**Not covered**

* Actually triggering and counting interrupts — only the edge configuration is
  verified.
* Electrical validation of pin levels (no loopback wiring is assumed).

## Prerequisites

* **Hardware:** none beyond the GPIO controller itself. Pins listed in
  `GPIO_PINS` must be free (not claimed by a kernel driver), otherwise the
  export fails and the pin is skipped with a warning.
* **Target tools:** `gpioinfo` (libgpiod) — only needed for the line-count
  check; if absent the check is not emitted.
* **Root:** required. Exporting pins via `/sys/class/gpio/export` and writing
  values needs write access to sysfs.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GPIO_COUNT` | `"1"` | Number of GPIO chips to iterate over (`gpio0` … `gpio<COUNT-1>`) |
| `GPIO{N}_DEV` | `/dev/gpiochip0` | Character device node for chip `N` |
| `GPIO{N}_CHIP` | `gpiochip0` | sysfs chip name under `/sys/class/gpio/`; empty skips the chip and controller checks |
| `GPIO{N}_CONTROLLER` | `""` | Expected value of `/sys/class/gpio/<chip>/label`; empty = check not emitted |
| `GPIO{N}_NLINES` | `"0"` | Expected line count; `0` (or `gpioinfo` missing) = check not emitted |
| `GPIO_PINS` | `""` | Space-separated `<chip_label>:<pin>:<direction[.edge]>:<label>` entries. `direction` = `in`\|`out`; `edge` = `rising`\|`falling`\|`both` (optional, IRQ pins only). Example: `GPIO0:5:in:SENSOR_IRQ GPIO0:6:out:LED_RED` |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

Only `GPIO{N}_DEV` is mandatory per chip; every other per-chip key is optional
and its absence simply removes the corresponding test case from the results.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `gpio<N>` for chip `N`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-GPIO-DEV-${label}` | | Device node exists and is a read/writable char device | Node missing or not R/W (remaining checks for this chip are abandoned) | — |
| `L-GPIO-CHIP-${label}` | | `/sys/class/gpio/<chip>` exists | Entry missing | Not emitted when `GPIO{N}_CHIP` is empty |
| `L-GPIO-CONTROLLER-${label}` | | `label` file matches `GPIO{N}_CONTROLLER` | Label differs or unreadable | Not emitted when `GPIO{N}_CONTROLLER` is empty |
| `L-GPIO-LINES-${label}` | | `gpioinfo` line count equals `GPIO{N}_NLINES` | Count differs or not numeric | Not emitted when `NLINES` is `0` or `gpioinfo` is missing |
| `L-GPIO-INPUT` | | Pin's `direction` reads `in` as configured | Direction differs | Not emitted for `out` pins |
| `L-GPIO-OUTPUT` | | Pin's `direction` reads `out` as configured | Direction differs | Not emitted for `in` pins |
| `L-GPIO-SENSED` | | `value` of an `in` pin read back non-empty | Value unreadable | Only for `in` pins whose direction matched |
| `L-GPIO-SET-HIGH-LOW` | | Writing `0` and `1` to `value` succeeds (emitted twice, once per level) | Write failed | Only for `out` pins whose direction matched |
| `L-GPIO-INT-SOURCE` | | Pin's sysfs `edge` file exists | File missing | Only for pins with an `.edge` suffix |
| `L-GPIO-INTERRUPT` | | `edge` file content matches the configured edge | Edge differs | Only for pins with an `.edge` suffix |

Pins that cannot be exported are reported as a warning only — no test case is
emitted for them. Pins already exported before the run are left exported;
pins exported by the script are unexported again afterwards.

## Running locally

```sh
cd automated/linux/gpio
GPIO_COUNT=1 \
GPIO0_DEV=/dev/gpiochip0 \
GPIO0_CHIP=gpiochip0 \
GPIO0_CONTROLLER=209c000.gpio \
GPIO0_NLINES=32 \
GPIO_PINS="GPIO0:5:in:SENSOR_IRQ GPIO0:6:out:LED_RED" \
bash gpio.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for
`L-GPIO-DEV-*`, `L-GPIO-LINES-*` (including raw `gpioinfo` output),
`L-GPIO-INPUT`, `L-GPIO-SENSED`, `L-GPIO-SET-HIGH-LOW`, `L-GPIO-INT-SOURCE`
and `L-GPIO-INTERRUPT`, each ending in a `RESULT:` line. LAVA surfaces these
logs alongside the test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-GPIO-DEV-*` fails | Wrong node path, or the test is not running as root |
| `L-GPIO-CHIP-*` fails | Kernel built without the legacy sysfs GPIO interface (`CONFIG_GPIO_SYSFS`) |
| `L-GPIO-CONTROLLER-*` fails | Expected label doesn't match the device-tree/ACPI label — read the actual value from `/sys/class/gpio/<chip>/label` |
| `L-GPIO-LINES-*` missing | `gpioinfo` not installed on the target, or `GPIO{N}_NLINES` left at `0` |
| "not exportable" warning | Pin is claimed by another driver, or the pin number is wrong (it is the global GPIO number, not the per-chip offset) |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_GPIO` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

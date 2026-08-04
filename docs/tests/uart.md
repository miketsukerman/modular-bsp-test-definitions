# uart (`adv-uart`)

UART checks: configured serial device-node presence, optional bus-controller
presence, `stty` configuration, hardware flow control, debug-console matching,
and functional loopback transfers.

* **Definition:** [`automated/linux/uart/uart.yaml`](../../automated/linux/uart/uart.yaml)
* **Script:** [`automated/linux/uart/uart.sh`](../../automated/linux/uart/uart.sh)

## Scope

**Covered**

* `/dev/tty*` exists and is a readable/writable character device.
* Optional bus-controller lookup through the shared `chk_bus` helper.
* `stty -F <device>` can read the port configuration.
* Hardware flow control can be enabled with `crtscts` when requested, or is
  reported pass without changing the port when not requested.
* Optional debug-console comparison against the kernel command line reported by
  `journalctl -b`.
* Loopback send/receive of short `TEST-N` patterns at configured baud/wiring
  combinations.

**Not covered**

* Long-duration serial reliability, modem-control line electrical validation, or
  peer-device protocol testing.
* Debug-console checks when `UART{N}_DEBUG_CONSOLE` is not enabled.

## Prerequisites

* **Hardware:** physical UART loopback cable for `UART{N}_LOOPBACK_TEST` entries;
  `2W` tests need TX/RX loopback, and `4W` tests also expect hardware flow
  control wiring.
* **Target tools:** `stty`, `timeout`, `head`, `journalctl` for debug-console
  checks, and `lspci`/`find`/`grep` as used by bus-controller helper checks.
* **Root:** required when the UART character device or sysfs/platform paths are
  not accessible to the test user.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `UART_COUNT` | `"1"` | Number of UART ports to iterate over (`ser0` … `ser<COUNT-1>`) |
| `UART{N}_DEV` | `/dev/ttyLP0` | Character device node for UART `N` |
| `UART{N}_BUS` | `soc` | Bus type passed to `chk_bus` (`soc` or `pci`); empty with `BUS_ID` empty skips the controller check |
| `UART{N}_BUS_ID` | `""` | Bus address/ID passed to `chk_bus`; empty skips the controller check |
| `UART{N}_HWFC` | `"0"` | `1` or `y` = require `crtscts`; any other value reports the HWFC test as pass |
| `UART{N}_DEBUG_CONSOLE` | `"0"` | `1` or `y` = verify the kernel debug console maps to this device |
| `UART{N}_LOOPBACK_TEST` | `skip` | `skip` or space-separated `<baud>:<2W|4W>` entries |
| `UART{N}_REFERENCE` | `""` | Human reference from YAML; not read by the script |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

`UART{N}_DEV` is mandatory for each configured port. If the device-node check
fails, all remaining checks for that port are not emitted.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `ser<N>` for UART `N`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-UART-DEV-${label}` | | Device node exists and is a read/writable char device | Node missing or not R/W (remaining checks for this UART are abandoned) | — |
| `L-UART-CONTROLLER-${label}` | | `chk_bus` finds the configured PCI or SoC controller | Controller not found, or unsupported bus type | Not emitted when `UART{N}_BUS` or `UART{N}_BUS_ID` is empty, or when the device-node check failed |
| `L-UART-CONFIGURE-F-${label}` | ✓ | `timeout 1 stty -F <device>` exits 0; also emitted as fail when loopback `stty` setup fails | `stty` read or loopback configuration command fails | Not emitted when the device-node check failed |
| `L-UART-HWFC-${label}` | | If HWFC requested, `stty crtscts` succeeds and `stty -a` contains `crtscts`; otherwise pass is emitted immediately | Requested HWFC cannot be set or confirmed | Not emitted when the device-node check failed |
| `L-UART-DEBUG-CONSOLE-${label}` | | If debug console requested, kernel `console=` device matches `UART{N}_DEV`; otherwise pass is emitted immediately | Requested debug-console device differs | Not emitted when the device-node check failed |
| `L-UART-LOOPBACK-F-${label}` | ✓ | Sent `TEST-N` pattern is read back for a configured loopback entry | Read times out or returned text differs | `skip` when `UART{N}_LOOPBACK_TEST` is empty or `skip`; not emitted for invalid wiring entries or when the device-node check failed |

Loopback entries with wiring other than `2W` or `4W` only print a warning and do
not emit a loopback result for that entry.

## Running locally

```sh
cd automated/linux/uart
UART_COUNT=1 \
UART0_DEV=/dev/ttyLP0 \
UART0_BUS=soc \
UART0_BUS_ID=30860000 \
UART0_HWFC=0 \
UART0_DEBUG_CONSOLE=0 \
UART0_LOOPBACK_TEST="115200:2W" \
bash uart.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for device,
controller, configure, HWFC, debug-console, and loopback checks that call
`verbose_log`. HWFC logs include `stty -a` output, and loopback logs include the
sent/received pattern and return code. LAVA surfaces these logs alongside the
test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-UART-DEV-*` fails | Wrong UART node, serial driver missing, or insufficient permissions |
| `L-UART-CONTROLLER-*` missing | `UART{N}_BUS` or `UART{N}_BUS_ID` is empty |
| `L-UART-CONFIGURE-F-*` fails | Port cannot be opened by `stty`, is busy, or the loopback baud/wiring setup failed |
| `L-UART-HWFC-*` fails | Hardware flow control was requested but the driver did not accept or report `crtscts` |
| `L-UART-DEBUG-CONSOLE-*` fails | Kernel `console=` device does not match the configured UART |
| `L-UART-LOOPBACK-F-*` skips | `UART{N}_LOOPBACK_TEST` is empty or `skip` |
| `L-UART-LOOPBACK-F-*` fails | Loopback cable missing, wrong baud/wiring mode, or the selected port is not connected to itself |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_UART` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

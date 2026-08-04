# can (`adv-can`)

CAN checks: network interface presence, optional bus-controller discovery,
optional clock-frequency matching, software loopback frame transfer, and
optional external peer-to-peer loopback between configured CAN interfaces.

* **Definition:** [`automated/linux/can/can.yaml`](../../automated/linux/can/can.yaml)
* **Script:** [`automated/linux/can/can.sh`](../../automated/linux/can/can.sh)

## Scope

**Covered**

* Each configured CAN network interface exists according to `ip addr show`.
* Optional CAN clock value from `ip -details -json link show` matches the
  expected frequency.
* Optional bus controller is found via the shared `chk_bus` helper.
* Software loopback sends one CAN frame and verifies that `candump` receives the
  exact frame at each configured bitrate.
* Optional external loopback sends one frame from one CAN interface to another.

**Not covered**

* Long-duration bus stability, error-counter, arbitration, or throughput tests.
* External loopback wiring unless `CAN_EXT_LOOPBACK` is configured.
* Multi-frame or multi-node CAN-network validation.

## Prerequisites

* **Hardware:** configured CAN controllers must be present. External loopback
  needs two CAN ports wired together according to `CAN_EXT_LOOPBACK`.
* **Target tools:** `ip` from iproute2, plus `candump` and `cansend` from
  can-utils. `lspci` is also needed when a `pci` bus controller is configured.
* **Root:** required. The script brings CAN interfaces down/up and changes CAN
  bitrate and loopback settings.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CAN_COUNT` | `"1"` | Number of CAN interfaces to iterate over (`can0` … `can<COUNT-1>`) |
| `CAN{N}_DEV` | `can0` | CAN network interface name for interface `N` |
| `CAN{N}_BUS` | `soc` | Bus type for controller discovery (`soc` or `pci`); empty = check not emitted |
| `CAN{N}_BUS_ID` | `""` | Bus identifier passed to `chk_bus`; empty = check not emitted |
| `CAN{N}_CLOCK` | `""` | Expected CAN clock in Hz from `ip -details -json`; empty = check not emitted |
| `CAN{N}_LOOPBACK_SPEEDS` | `"125000 500000"` | Space-separated bitrates for software loopback tests |
| `CAN_EXT_LOOPBACK` | `""` | Space-separated `<ifA>:<ifB>:<bitrate>` external loopback entries; empty = one skip result |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

`CAN{N}_DEV`, `CAN{N}_BUS`, and the other indexed defaults are provided for
`CAN0` by the YAML definition; additional interfaces must be supplied by board
parameters or the environment.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `can<N>` for interface
`N`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-CAN-DEV-${label}` | | `ip addr show <iface>` succeeds | Interface is missing (remaining checks for this interface are abandoned) | — |
| `L-CAN-CLOCK-${label}` | | Reported `clock` equals `CAN{N}_CLOCK` | Clock differs or cannot be parsed | Not emitted when `CAN{N}_CLOCK` is empty or the interface check failed |
| `L-CAN-CONTROLLER-${label}` | | `chk_bus` finds the configured controller | Controller not found or bus type unsupported | Not emitted when `CAN{N}_BUS` or `CAN{N}_BUS_ID` is empty, or the interface check failed |
| `L-CAN-LOOPBACK-F-${label}` | ✓ | Interface setup succeeds and `candump` receives the exact frame sent by `cansend` | Interface setup, send, receive, or frame comparison fails | Not emitted when the interface check failed or `CAN{N}_LOOPBACK_SPEEDS` is empty |
| `L-CAN-EXT-LOOP-F` | ✓ | External interface setup succeeds and `candump` on the peer receives the exact frame sent by `cansend` | Interface setup, send, receive, or frame comparison fails | One skip is emitted when `CAN_EXT_LOOPBACK` is empty |

`L-CAN-LOOPBACK-F-*` is emitted once per configured bitrate. `L-CAN-EXT-LOOP-F`
is emitted once per configured external loopback entry, or once as skip when no
entries are configured.

## Running locally

```sh
cd automated/linux/can
CAN_COUNT=1 \
CAN0_DEV=can0 \
CAN0_BUS=soc \
CAN0_BUS_ID=308c0000 \
CAN0_CLOCK=40000000 \
CAN0_LOOPBACK_SPEEDS="125000 500000" \
CAN_EXT_LOOPBACK="" \
bash can.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for CAN device
presence, clock checks, and loopback setup diagnostics that use `verbose_log` or
`verbose_cmd`. LAVA surfaces these logs alongside the test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-CAN-DEV-*` fails | Wrong interface name, CAN driver not loaded, or device tree/ACPI disabled the controller |
| `L-CAN-CLOCK-*` fails or is missing | `CAN{N}_CLOCK` does not match the kernel-reported value, or the parameter is empty |
| `L-CAN-CONTROLLER-*` fails | Wrong `CAN{N}_BUS_ID`, unsupported bus type, or missing `lspci` for PCI checks |
| `L-CAN-LOOPBACK-F-*` fails | Missing can-utils, insufficient privileges, bitrate unsupported, or loopback setup failed |
| `L-CAN-EXT-LOOP-F` skips | `CAN_EXT_LOOPBACK` was left empty |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_CAN` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

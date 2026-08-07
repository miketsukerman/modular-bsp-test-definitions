# Modular BSP Test Definitions

Advantech BSP QA – a modular suite of [LAVA](https://www.lavasoftware.org/)
*Lava-Test Test Definition 1.0* test cases for validating Board Support
Packages (BSPs) on embedded Linux targets (Yocto and Debian).

Each hardware subsystem (audio, CAN, CPU, Ethernet, GPIO, …) is a
self-contained module made of:

* a **YAML** test definition (metadata, tunable `params`, and `run` steps), and
* a **shell** script that performs the checks and emits LAVA results.

Modules are parameterised entirely through the YAML `params` block, so the same
test logic runs unchanged across different boards — only the parameter values
(populated per board) change.  Every module accepts a `VERBOSE` parameter
(default `"0"`); set it to `"1"` to enable per-test-case diagnostic log files
that are captured and surfaced by LAVA.

## Repository layout

```
.github/workflows/checks.yml   # CI: shellcheck, yamllint and consistency checks
requirements.yaml              # Test-case description metadata (see below)
automated/linux/
├── lib/
│   └── adv-test-lib.sh        # Shared helper library, sourced by every module
├── utils/
│   └── send-to-lava.sh        # Translates result.txt into LAVA signals
├── tools/
│   ├── conf_to_yaml.py        # Generates per-module params YAML from a board .conf
│   ├── check_requirements.py  # Checks requirements.yaml against the emitted IDs
│   └── check_docs.py          # Checks the docs against the repository contents
├── audio/   (audio.sh   + audio.yaml)
├── can/     (can.sh     + can.yaml)
├── context/ (context.sh + context.yaml)
├── cpu/     (cpu.sh     + cpu.yaml)
├── disk/    (disk.sh    + disk.yaml)
├── eth/     (eth.sh     + eth.yaml)
├── gpio/    (gpio.sh    + gpio.yaml)
├── gpu/     (gpu.sh     + gpu.yaml)
├── i2c/     (i2c.sh     + i2c.yaml)
├── npu/     (npu.sh     + npu.yaml)
├── optee/   (optee.sh   + optee.yaml)
├── pwm/     (pwm.sh     + pwm.yaml)
├── ram/     (ram.sh     + ram.yaml)
├── rtc/     (rtc.sh + rtc.yaml, rtc-suspend.sh + rtc-suspend.yaml)
├── spi/     (spi.sh     + spi.yaml)
├── thermal/ (thermal.sh + thermal.yaml)
├── tpm/     (tpm.sh     + tpm.yaml)
├── uart/    (uart.sh    + uart.yaml)
├── usb/     (usb.sh     + usb.yaml)
└── watchdog/(watchdog.sh + watchdog.yaml, watchdog-reboot.sh + watchdog-reboot.yaml)
```

## Test modules at a glance

| Module          | Definition file(s)                     | What it checks |
|-----------------|----------------------------------------|----------------|
| [audio](docs/tests/audio.md)| `audio.yaml`                           | Playback/capture device enumeration; functional loopback (skip stub) |
| [can](docs/tests/can.md)| `can.yaml`                             | CAN interface, controller, clock, SW loopback; external loopback (skip) |
| [context](docs/tests/context.md)| `context.yaml`                         | Distro ID/version, kernel min version, CPU model, BIOS date |
| [cpu](docs/tests/cpu.md)| `cpu.yaml`                             | CPU count, C-states, cpufreq min/max, governors, suspend states |
| [disk](docs/tests/disk.md)| `disk.yaml`                            | rootfs mount/mode, block device type/sectors, eMMC CSD, dd throughput |
| [eth](docs/tests/eth.md)| `eth.yaml`                             | Device, controller, link speed, IPv4/IPv6, WoL, DNS, ping, iperf3 |
| [gpio](docs/tests/gpio.md)| `gpio.yaml`                            | gpiochip node/label/line count, per-pin direction/read/set/IRQ |
| [gpu](docs/tests/gpu.md)| `gpu.yaml`                             | DRI/KMS nodes, GL/GLES, Wayland, Vulkan, VA-API, DRM/LVDS/backlight |
| [i2c](docs/tests/i2c.md)| `i2c.yaml`                             | I2C device nodes, R/W access, controller name |
| [npu](docs/tests/npu.md)| `npu.yaml`                             | NPU device node R/W access, bus controller presence |
| [optee](docs/tests/optee.md)| `optee.yaml`                           | OP-TEE device node, `xtest` regression (quick/full) |
| [pwm](docs/tests/pwm.md)| `pwm.yaml`                             | PWM chip presence, bus controller, backlight brightness |
| [ram](docs/tests/ram.md)| `ram.yaml`                             | Per-slot size/speed (dmidecode), min memory, memtester stability |
| [rtc](docs/tests/rtc.md)| `rtc.yaml`, `rtc-suspend.yaml`         | RTC node, hwclock get/set, wakeup flag; suspend/resume (separate job) |
| [spi](docs/tests/spi.md)| `spi.yaml`                             | spidev node R/W access, `spidev_test` loopback |
| [thermal](docs/tests/thermal.md)| `thermal.yaml`                         | thermal_zone presence and temperature within MIN/MAX bounds |
| [tpm](docs/tests/tpm.md)| `tpm.yaml`                             | TPM node, self-test, manufacturer, capabilities, PCR readability |
| [uart](docs/tests/uart.md)| `uart.yaml`                            | UART node, controller, stty config, HWFC, debug console, loopback |
| [usb](docs/tests/usb.md)| `usb.yaml`                             | USB host enumeration, plugged-device checks, OTG gadget config |
| [watchdog](docs/tests/watchdog.md)| `watchdog.yaml`, `watchdog-reboot.yaml`| Watchdog node, daemon running; reboot test (separate job) |

Each module name links to its own suite document under
[`docs/tests/`](docs/tests/README.md), which covers scope, prerequisites, every
parameter, every LAVA test-case ID with its pass/fail/skip criteria, a local
run example and troubleshooting notes. The same index also carries a global
test-case ID → suite lookup table. See
[`docs/lava-usage.md`](docs/lava-usage.md) for how to assemble these modules
into a complete LAVA job (with a full annotated job example). To add your own
module or test case, see
[`docs/extending-tests.md`](docs/extending-tests.md).

> **Disruptive tests run as separate jobs.** `rtc-suspend` and
> `watchdog-reboot` change the board's power state (suspend/reboot) and are
> therefore split into their own YAML job definitions so they don't disrupt
> other test sessions running in the same LAVA job.

## How a module runs

Every module YAML ends with the same three-step `run` block, for example:

```yaml
run:
  steps:
    - cd ./automated/linux/i2c
    - bash i2c.sh
    - bash ../utils/send-to-lava.sh ./output/result.txt
```

1. **`cd`** into the module directory.
2. **Run the module script.** It sources `../lib/adv-test-lib.sh`, reads its
   parameters from the environment (LAVA exports `params` as env vars), runs
   the checks, and writes one result line per test case to `./output/result.txt`.
3. **`send-to-lava.sh`** parses `result.txt` and emits the corresponding LAVA
   signals (`lava-test-case` / `LAVA_SIGNAL_TESTCASE`).

### Running a module locally (outside LAVA)

```sh
cd automated/linux/i2c
I2C_COUNT=1 I2C0_DEV=/dev/i2c-0 I2C0_CONTROLLER="21a0000.i2c" bash i2c.sh
cat output/result.txt
```

`send-to-lava.sh` degrades gracefully when the `lava-test-case` binary is
absent (it prints `LAVA_SIGNAL_*` lines instead), so it can be invoked outside
of LAVA for debugging.

## Result file format

Module scripts write `output/result.txt` with one entry per line. The reporter
helpers in `adv-test-lib.sh` produce these formats:

```
<test_case_id> <pass|fail|skip|unknown>
<test_case_id> <pass|fail|skip|unknown> <measurement> [units]
lava-test-set start <set_name>
lava-test-set stop
```

* `report_pass` / `report_fail` / `report_skip` / `report_unknown` emit the
  first form.
* `report_metric <id> <result> <measurement> [units]` emits the measurement
  form (used e.g. for RAM size and throughput numbers).

### Test-case ID conventions

* IDs are prefixed with `L-` (Linux) followed by the subsystem, e.g.
  `L-ETH-LINK`, `L-CPU-NPROC`.
* A trailing **`:F`** marks a **functional** test — one that exercises real
  hardware behaviour (loopback, throughput, suspend/reboot) rather than mere
  presence/enumeration. Functional tests often require extra hardware (loopback
  cables, an iperf3 peer, a display) and become **skip** stubs when their
  prerequisites or parameters are absent.
* Per-instance IDs append the instance label after a **`·`** (U+00B7 middle
  dot), e.g. `L-ETH-LINK·eth0`.
* `lava_id()` sanitises IDs for LAVA by replacing both `·` and `:` with `-`,
  so `L-ETH-TX-THROUGHPUT:F·eth0` is reported as
  `L-ETH-TX-THROUGHPUT-F-eth0`. The IDs listed in the suite documents under
  `docs/tests/` use the sanitised form.

## Shared helper library (`lib/adv-test-lib.sh`)

Sourced by every module script. Key helpers:

| Helper | Purpose |
|--------|---------|
| `create_out_dir` | Create the `output/` directory for `result.txt`. |
| `report_pass/fail/skip/unknown <id>` | Emit a single result line. |
| `report_metric <id> <result> <meas> [units]` | Emit a measurement result line. |
| `run_adv_test <id> <cmd…>` | Run a command; pass on exit 0, fail otherwise. |
| `lava_id <id>` | Sanitise `·`/`:` to `-` for LAVA. |
| `check_root` | True if running as root (uid 0). |
| `chk_cmd <cmd>` | True if a command exists in `PATH`. |
| `chk_rw_cdev/chk_rw_bdev <path>` | Verify a char/block device exists and is R/W. |
| `chk_bus pci\|soc …` | Verify a bus controller exists (lspci or platform sysfs). |
| `get_ip <iface> [4\|6]` | Read an interface's IPv4/IPv6 address. |
| `disk_type` / `disk_exists` / `drop_caches` | Disk helpers. |
| `physical_ram_MB` / `physical_ram_MT` | RAM size/speed via dmidecode or iomem. |
| `get_distro_id` / `get_distro_ver` / `is_yocto` | OS/distro detection. |

## Generating board parameters (`tools/conf_to_yaml.py`)

Boards are described with a bash-style `.conf` file that defines `CFGA_*`
associative arrays (e.g. `CFGA_ETH`, `CFGA_I2C`). `conf_to_yaml.py` converts
that file into per-module `params.yaml` fragments that can be merged into the
LAVA test definitions:

```sh
python3 automated/linux/tools/conf_to_yaml.py path/to/board.conf --out-dir /tmp/yaml
```

This writes `<out-dir>/<module>/params.yaml` for every supported module, so a
new board only needs its `.conf` authored once rather than each module YAML
edited by hand.

## Test case description metadata (`requirements.yaml`)

Result lines only carry a test-case ID and a result. To let report consumers
show *what a test case means* instead of a derived id string, every requirement
is described once in the machine-readable catalogue
[`requirements.yaml`](requirements.yaml) at the repository root.

[bsp-registry-tools](https://github.com/miketsukerman/bsp-registry-tools)
discovers the file automatically at the root of the cloned test-definitions
repository — no registry-side configuration is required.

### Entry schema

```yaml
requirements:
  L-I2C-DEV:
    description: The configured I2C bus device node exists and is usable.
    verifies: Checks that the configured `/dev/i2c-N` node is a readable/writable character device.
    category: I2C
    remarks: When this fails the remaining checks for the bus are abandoned.
    version: 1
```

| Field | Meaning |
|-------|---------|
| `description` | What the requirement means (its purpose), one board-agnostic sentence. |
| `verifies` | How it is asserted — the mechanism used by the script. |
| `category` | Subsystem grouping used by the report's category table (one of the 20 module subsystems: Audio, CAN, Context, CPU, Disk, Ethernet, GPIO, GPU, I2C, NPU, OP-TEE, PWM, RAM, RTC, SPI, Thermal, TPM, UART, USB, Watchdog). |
| `remarks` | Prerequisites and skip conditions, including the extra hardware that functional (`:F`) cases need. |
| `version` | Requirement version, starting at `1`; bump it when the *meaning* changes, not when the wording is polished. |
| `specification` | Expected value. Left empty here: expectations are board-specific and live in the board `.conf` → `params.yaml`. A board overlay catalogue may supply them, either as a scalar or as an instance → value mapping. |
| `manual` | `true` for requirements verified by manual inspection. Nothing in this repository emits manual results today. |

A consumer applies per-field precedence *signal attribute > catalogue entry >
derived*, so anything omitted here simply falls back to the humanised ID.

### Keying rule and instance resolution

Catalogue keys are the **base requirement ID in sanitised form, without the
instance suffix**:

* `L-I2C-DEV` covers `L-I2C-DEV-i2c0`, `L-I2C-DEV-i2c1`, …
* `L-CAN-LOOPBACK-F` (note `:F` → `-F`) covers `L-CAN-LOOPBACK-F-can0`, …
* IDs that are already instance-free — `L-OPTEE-DEV`, `L-DISK-ROOTFS-FOUND`,
  `L-GPIO-INPUT` — are keyed as-is.

An emitted ID is resolved by exact match first, then by longest-prefix match
where the character after the prefix is one of `- _ . : /`; the remainder is the
*instance key* used to look up a per-instance `specification`. Because the
instance suffix must be separated that way, `L-DNS-IPV4`/`L-DNS-IPV6` and
`L-ETH-IPV4-PING`/`L-ETH-IPV6-PING` are keyed in full.

### Keeping the catalogue in sync

`tools/check_requirements.py` statically extracts every requirement ID the
module scripts can emit, reduces it to its base form and compares it with the
catalogue:

```sh
python3 automated/linux/tools/check_requirements.py
```

It exits non-zero when an emitted ID has no catalogue entry, when a catalogue
entry matches no emitted ID, or when catalogue keys are duplicated. It also
lists prefix-shadowing keys (e.g. `L-SPI-DEV` ⊂ `L-SPI-DEV-TEST-F`), which
resolve correctly by longest match but are worth knowing about when adding new
IDs.

An alternative to the shared catalogue is a `metadata.test_cases:` block inside
a single module YAML, which overrides the catalogue for that suite only. It is
deliberately unused here: it adds a non-standard key to a *Lava-Test Test
Definition 1.0* document and scatters the metadata across the module files.

## Continuous integration

[`.github/workflows/checks.yml`](.github/workflows/checks.yml) runs on every
push to `main` and on every pull request, and can also be started manually. It
runs the same checks you can run locally:

| Job | Command | What it guards |
|-----|---------|----------------|
| `shellcheck` | `shellcheck --severity=warning automated/linux/*/*.sh` | The module scripts and the shared library stay lint-clean. [`.shellcheckrc`](.shellcheckrc) points shellcheck at `lib/adv-test-lib.sh` so sourced helpers are followed. |
| `yamllint` | `yamllint --strict requirements.yaml automated/linux/*/*.yaml` | The test definitions and the catalogue stay valid, consistently formatted YAML. Rules live in [`.yamllint`](.yamllint). |
| `consistency` | `check_requirements.py` and `check_docs.py` | The catalogue and the documentation stay in sync with the modules (see below). |

### Keeping the documentation in sync

`tools/check_docs.py` compares the documentation with the repository contents:

```sh
python3 automated/linux/tools/check_docs.py
```

It exits non-zero when

* a module has no suite document under `docs/tests/`, or a suite document has
  no module;
* a module is missing from the *Test modules at a glance* table in this file or
  from the suite table in `docs/tests/README.md`, or those tables name a
  definition file that does not exist or a LAVA name that differs from the
  YAML `metadata.name`;
* a module ships a `*.yaml` without its `*.sh` (or vice versa), or a module
  YAML's `run` steps `cd` into the wrong directory;
* a suite document's *Test cases* table misses a test-case ID the module's
  scripts can emit, or describes one they cannot;
* the [test-case ID index](docs/tests/README.md#test-case-id-index) misses an
  emitted ID, lists an ID no module emits, or attributes an ID to the wrong
  suite;
* a relative Markdown link points at a missing file or heading.

Test-case IDs are compared in their base form, so `L-I2C-DEV-i2c${n}`,
`L-I2C-DEV-${label}` and `L-I2C-DEV-i2c{N}` all match the `L-I2C-DEV` the
script emits.

## Supported OS / scope

All modules declare:

* `os: [yocto, debian]`
* `scope: [functional]`
* `devices: [all]`
* `maintainer: qa@advantech.com`

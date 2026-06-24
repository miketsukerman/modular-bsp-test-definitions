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
(populated per board) change.

## Repository layout

```
automated/linux/
├── lib/
│   └── adv-test-lib.sh        # Shared helper library, sourced by every module
├── utils/
│   └── send-to-lava.sh        # Translates result.txt into LAVA signals
├── tools/
│   └── conf_to_yaml.py        # Generates per-module params YAML from a board .conf
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
| audio           | `audio.yaml`                           | Playback/capture device enumeration; functional loopback (skip stub) |
| can             | `can.yaml`                             | CAN interface, controller, clock, SW loopback; external loopback (skip) |
| context         | `context.yaml`                         | Distro ID/version, kernel min version, CPU model, BIOS date |
| cpu             | `cpu.yaml`                             | CPU count, C-states, cpufreq min/max, governors, suspend states |
| disk            | `disk.yaml`                            | rootfs mount/mode, block device type/sectors, eMMC CSD, dd throughput |
| eth             | `eth.yaml`                             | Device, controller, link speed, IPv4/IPv6, WoL, DNS, ping, iperf3 |
| gpio            | `gpio.yaml`                            | gpiochip node/label/line count, per-pin direction/read/set/IRQ |
| gpu             | `gpu.yaml`                             | DRI/KMS nodes, GL/GLES, Wayland, Vulkan, VA-API, DRM/LVDS/backlight |
| i2c             | `i2c.yaml`                             | I2C device nodes, R/W access, controller name |
| npu             | `npu.yaml`                             | NPU device node R/W access, bus controller presence |
| optee           | `optee.yaml`                           | OP-TEE device node, `xtest` regression (quick/full) |
| pwm             | `pwm.yaml`                             | PWM chip presence, bus controller, backlight brightness |
| ram             | `ram.yaml`                             | Per-slot size/speed (dmidecode), min memory, memtester stability |
| rtc             | `rtc.yaml`, `rtc-suspend.yaml`         | RTC node, hwclock get/set, wakeup flag; suspend/resume (separate job) |
| spi             | `spi.yaml`                             | spidev node R/W access, `spidev_test` loopback |
| thermal         | `thermal.yaml`                         | thermal_zone presence and temperature within MIN/MAX bounds |
| tpm             | `tpm.yaml`                             | TPM node, self-test, manufacturer, capabilities, PCR readability |
| uart            | `uart.yaml`                            | UART node, controller, stty config, HWFC, debug console, loopback |
| usb             | `usb.yaml`                             | USB host enumeration, plugged-device checks, OTG gadget config |
| watchdog        | `watchdog.yaml`, `watchdog-reboot.yaml`| Watchdog node, daemon running; reboot test (separate job) |

See [`docs/test-reference.md`](docs/test-reference.md) for the full per-module
parameter reference and the list of LAVA test-case IDs each module emits, and
[`docs/lava-usage.md`](docs/lava-usage.md) for how to assemble these modules
into a complete LAVA job (with a full annotated job example).

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
  `L-ETH-TX-THROUGHPUT-F-eth0`. The IDs listed in `docs/test-reference.md` use
  the sanitised form.

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

## Supported OS / scope

All modules declare:

* `os: [yocto, debian]`
* `scope: [functional]`
* `devices: [all]`
* `maintainer: qa@advantech.com`

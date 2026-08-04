# Test suite index

One document per test suite (module) in `automated/linux/`. Each suite document
covers the module's scope, prerequisites, every YAML parameter, every LAVA
test-case ID with its pass/fail/skip criteria, a local invocation example and
troubleshooting notes.

* New to the suite? Start with the [repository README](../../README.md).
* Assembling a LAVA job? See [`lava-usage.md`](../lava-usage.md).
* Writing a new module? See [`extending-tests.md`](../extending-tests.md).

Legend: **HW** – some test cases need extra hardware (loopback cable, peer
host, display) and become `skip` stubs otherwise. **Disruptive** – the module
ships an extra definition that changes the board's power state and must run in
[its own LAVA job](../lava-usage.md#disruptive-tests-belong-in-their-own-jobs).

| Suite | LAVA name | Definition file(s) | What it checks | HW | Disruptive |
|-------|-----------|--------------------|----------------|:--:|:----------:|
| [audio](audio.md) | `adv-audio` | `audio.yaml` | Playback/capture device enumeration; functional loopback (skip stub) | ✓ | |
| [can](can.md) | `adv-can` | `can.yaml` | CAN interface, controller, clock, SW loopback; external loopback | ✓ | |
| [context](context.md) | `adv-context` | `context.yaml` | Distro ID/version, kernel min version, CPU model, BIOS date | | |
| [cpu](cpu.md) | `adv-cpu` | `cpu.yaml` | CPU count, C-states, cpufreq min/max, governors, suspend states | | |
| [disk](disk.md) | `adv-disk` | `disk.yaml` | rootfs mount/mode, block device type/sectors, eMMC CSD, dd throughput | | |
| [eth](eth.md) | `adv-eth` | `eth.yaml` | Device, controller, link speed, IPv4/IPv6, WoL, DNS, ping, iperf3 | ✓ | |
| [gpio](gpio.md) | `adv-gpio` | `gpio.yaml` | gpiochip node/label/line count, per-pin direction/read/set/IRQ | | |
| [gpu](gpu.md) | `adv-gpu` | `gpu.yaml` | DRI/KMS nodes, GL/GLES, Wayland, Vulkan, VA-API, DRM/LVDS/backlight | ✓ | |
| [i2c](i2c.md) | `adv-i2c` | `i2c.yaml` | I2C device nodes, R/W access, controller name | | |
| [npu](npu.md) | `adv-npu` | `npu.yaml` | NPU device node R/W access, bus controller presence | | |
| [optee](optee.md) | `adv-optee` | `optee.yaml` | OP-TEE device node, `xtest` regression (quick/full) | | |
| [pwm](pwm.md) | `adv-pwm` | `pwm.yaml` | PWM chip presence, bus controller, backlight brightness | | |
| [ram](ram.md) | `adv-ram` | `ram.yaml` | Per-slot size/speed (dmidecode), min memory, memtester stability | | |
| [rtc](rtc.md) | `adv-rtc`, `adv-rtc-suspend` | `rtc.yaml`, `rtc-suspend.yaml` | RTC node, hwclock get/set, wakeup flag; suspend/resume | | ✓ |
| [spi](spi.md) | `adv-spi` | `spi.yaml` | spidev node R/W access, `spidev_test` loopback | ✓ | |
| [thermal](thermal.md) | `adv-thermal` | `thermal.yaml` | thermal_zone presence and temperature within MIN/MAX bounds | | |
| [tpm](tpm.md) | `adv-tpm` | `tpm.yaml` | TPM node, self-test, manufacturer, capabilities, PCR readability | | |
| [uart](uart.md) | `adv-uart` | `uart.yaml` | UART node, controller, stty config, HWFC, debug console, loopback | ✓ | |
| [usb](usb.md) | `adv-usb` | `usb.yaml` | USB host enumeration, plugged-device checks, OTG gadget config | ✓ | |
| [watchdog](watchdog.md) | `adv-watchdog`, `adv-watchdog-reboot` | `watchdog.yaml`, `watchdog-reboot.yaml` | Watchdog node, daemon running; reboot test | | ✓ |

## Test-case ID index

Every LAVA test-case ID the suite can emit, in sanitised form (see the
[ID conventions](../../README.md#test-case-id-conventions)). `${n}` and `${k}`
stand for the zero-based instance suffix the script appends.

| Test case ID | Suite |
|--------------|-------|
| `L-AUDIO-PLAYBACK-DEV-pb${n}` | [audio](audio.md) |
| `L-AUDIO-PLAYBACK-F` | [audio](audio.md) |
| `L-AUDIO-RECORDING-DEV-cap${n}` | [audio](audio.md) |
| `L-AUDIO-RECORDING-F` | [audio](audio.md) |
| `L-BIOS-DATE-MINIMUM` | [context](context.md) |
| `L-CAN-CLOCK-can${n}` | [can](can.md) |
| `L-CAN-CONTROLLER-can${n}` | [can](can.md) |
| `L-CAN-DEV-can${n}` | [can](can.md) |
| `L-CAN-EXT-LOOP-F` | [can](can.md) |
| `L-CAN-LOOPBACK-F-can${n}` | [can](can.md) |
| `L-CPU-C-STATES-${k}` | [cpu](cpu.md) |
| `L-CPU-FREQ-SCALING-MAX-${k}` | [cpu](cpu.md) |
| `L-CPU-FREQ-SCALING-MIN-${k}` | [cpu](cpu.md) |
| `L-CPU-MODEL` | [context](context.md) |
| `L-CPU-NPROC` | [cpu](cpu.md) |
| `L-CPU-POWER-STATE-SUSPENSION` | [cpu](cpu.md) |
| `L-CPU-SCALING-GOVERNOR-${k}` | [cpu](cpu.md) |
| `L-CPU-SCALING-GOVERNOR-SET-F-${k}` | [cpu](cpu.md) |
| `L-DISK-DEV-disk${n}` | [disk](disk.md) |
| `L-DISK-EXTCSD-READABLE-disk${n}` | [disk](disk.md) |
| `L-DISK-READ-THROUGHPUT-F-disk${n}` | [disk](disk.md) |
| `L-DISK-ROOTFS-FOUND` | [disk](disk.md) |
| `L-DISK-ROOTFS-MODE` | [disk](disk.md) |
| `L-DISK-SECTORS-disk${n}` | [disk](disk.md) |
| `L-DISK-TYPE-disk${n}` | [disk](disk.md) |
| `L-DISK-WRITE-THROUGHPUT-F-disk${n}` | [disk](disk.md) |
| `L-DNS-IPV${proto}` | [eth](eth.md) |
| `L-ETH-CONFIGURED-eth${n}` | [eth](eth.md) |
| `L-ETH-CONTROLLER-eth${n}` | [eth](eth.md) |
| `L-ETH-DEV-eth${n}` | [eth](eth.md) |
| `L-ETH-IPV${proto}-PING` | [eth](eth.md) |
| `L-ETH-IPV4-ADDRESS-eth${n}` | [eth](eth.md) |
| `L-ETH-IPV6-ADDRESS-eth${n}` | [eth](eth.md) |
| `L-ETH-LINK-eth${n}` | [eth](eth.md) |
| `L-ETH-RX-THROUGHPUT-F-eth${n}` | [eth](eth.md) |
| `L-ETH-TX-THROUGHPUT-F-eth${n}` | [eth](eth.md) |
| `L-ETH-WAKEUP-ENABLED-eth${n}` | [eth](eth.md) |
| `L-ETH-WAKEUP-FEATURED-eth${n}` | [eth](eth.md) |
| `L-GPIO-CHIP-gpio${n}` | [gpio](gpio.md) |
| `L-GPIO-CONTROLLER-gpio${n}` | [gpio](gpio.md) |
| `L-GPIO-DEV-gpio${n}` | [gpio](gpio.md) |
| `L-GPIO-INPUT` | [gpio](gpio.md) |
| `L-GPIO-INT-SOURCE` | [gpio](gpio.md) |
| `L-GPIO-INTERRUPT` | [gpio](gpio.md) |
| `L-GPIO-LINES-gpio${n}` | [gpio](gpio.md) |
| `L-GPIO-OUTPUT` | [gpio](gpio.md) |
| `L-GPIO-SENSED` | [gpio](gpio.md) |
| `L-GPIO-SET-HIGH-LOW` | [gpio](gpio.md) |
| `L-GPU-BACKLIGHT-DEV-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-BACKLIGHT-F-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-BACKLIGHT-RESTORE-F-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRI-KMS-DEV-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRM-CONNECTOR-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRM-CONNECTOR-ENCODER-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRM-CONNECTOR-REFRESH-RATE-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRM-CONNECTOR-RESOLUTION-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRM-LVDS-DEV-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRM-LVDS-ENABLED-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-DRM-LVDS-MODULE-gpu${n}` | [gpu](gpu.md) |
| `L-GPU-OPENGL-ES-F` | [gpu](gpu.md) |
| `L-GPU-OPENGL-F` | [gpu](gpu.md) |
| `L-GPU-VA-HW-CODECS` | [gpu](gpu.md) |
| `L-GPU-VA-HW-FFMPEG` | [gpu](gpu.md) |
| `L-GPU-VULKAN-DEV` | [gpu](gpu.md) |
| `L-GPU-WAYLAND` | [gpu](gpu.md) |
| `L-I2C-CONTROLLER-i2c${n}` | [i2c](i2c.md) |
| `L-I2C-DEV-i2c${n}` | [i2c](i2c.md) |
| `L-NPU-CONTROLLER-npu${n}` | [npu](npu.md) |
| `L-NPU-DEV-npu${n}` | [npu](npu.md) |
| `L-OPTEE-DEV` | [optee](optee.md) |
| `L-OPTEE-XTEST-F` | [optee](optee.md) |
| `L-PWM-BACKLIGHT-BRIGHTNESS-DEV` | [pwm](pwm.md) |
| `L-PWM-CONTROLLER-pwm${n}` | [pwm](pwm.md) |
| `L-PWM-DEV-pwm${n}` | [pwm](pwm.md) |
| `L-RAM-AVAILABLE-MIN` | [ram](ram.md) |
| `L-RAM-AVAILABLE-TOTAL` | [ram](ram.md) |
| `L-RAM-SIZE-slot${n}` | [ram](ram.md) |
| `L-RAM-SPEED-slot${n}` | [ram](ram.md) |
| `L-RAM-STABILITY-F` | [ram](ram.md) |
| `L-RTC-DEFAULT` | [rtc](rtc.md) |
| `L-RTC-DEV-rtc${n}` | [rtc](rtc.md) |
| `L-RTC-GET-F-rtc${n}` | [rtc](rtc.md) |
| `L-RTC-SET-F-rtc${n}` | [rtc](rtc.md) |
| `L-RTC-WAKEUP-rtc${n}` | [rtc](rtc.md) |
| `L-SPI-DEV-spi${n}` | [spi](spi.md) |
| `L-SPI-DEV-TEST-F-spi${n}` | [spi](spi.md) |
| `L-SUSPEND-WAKEUP-F-rtc0` | [rtc](rtc.md) (rtc-suspend) |
| `L-SW-DISTRO-ID` | [context](context.md) |
| `L-SW-DISTRO-VER` | [context](context.md) |
| `L-SW-KERNEL-MIN-VER` | [context](context.md) |
| `L-THERMAL-ZONE-DEV-tz${n}` | [thermal](thermal.md) |
| `L-THERMAL-ZONE-MAX-tz${n}` | [thermal](thermal.md) |
| `L-THERMAL-ZONE-MIN-tz${n}` | [thermal](thermal.md) |
| `L-THERMAL-ZONE-TEMP-tz${n}` | [thermal](thermal.md) |
| `L-TPM-CAPABILITIES-tpm${n}` | [tpm](tpm.md) |
| `L-TPM-CONTROLLER-tpm${n}` | [tpm](tpm.md) |
| `L-TPM-DEV-tpm${n}` | [tpm](tpm.md) |
| `L-TPM-PCR-READABLE-F-tpm${n}` | [tpm](tpm.md) |
| `L-TPM-SELF-TEST-F-tpm${n}` | [tpm](tpm.md) |
| `L-UART-CONFIGURE-F-ser${n}` | [uart](uart.md) |
| `L-UART-CONTROLLER-ser${n}` | [uart](uart.md) |
| `L-UART-DEBUG-CONSOLE-ser${n}` | [uart](uart.md) |
| `L-UART-DEV-ser${n}` | [uart](uart.md) |
| `L-UART-HWFC-ser${n}` | [uart](uart.md) |
| `L-UART-LOOPBACK-F-ser${n}` | [uart](uart.md) |
| `L-USB-HOST-DEV` | [usb](usb.md) |
| `L-USB-OTG-CONF-${cfg_key}` | [usb](usb.md) |
| `L-USB-OTG-ETH-F` | [usb](usb.md) |
| `L-USB-PLUGGED-DEV-F-dev${n}` | [usb](usb.md) |
| `L-WATCHDOG-DEV-watchdog${n}` | [watchdog](watchdog.md) |
| `L-WATCHDOG-REBOOT-F` | [watchdog](watchdog.md) (watchdog-reboot) |
| `L-WATCHDOG-SERVICE` | [watchdog](watchdog.md) |

## Shared components

These are not test suites, but every suite depends on them:

| Component | Purpose | Reference |
|-----------|---------|-----------|
| [`lib/adv-test-lib.sh`](../../automated/linux/lib/adv-test-lib.sh) | Helper library sourced by every module script: result reporters, device/bus checks, verbose logging | [README – shared helper library](../../README.md#shared-helper-library-libadv-test-libsh) |
| [`utils/send-to-lava.sh`](../../automated/linux/utils/send-to-lava.sh) | Translates `output/result.txt` into LAVA test-case signals and attaches verbose logs | [README – how a module runs](../../README.md#how-a-module-runs) |
| [`tools/conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py) | Generates per-module `params.yaml` from a board `.conf` file | [README – generating board parameters](../../README.md#generating-board-parameters-toolsconf_to_yamlpy) |

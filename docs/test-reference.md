# Test Reference

Per-module reference for every test definition in `automated/linux/`. For each
module you'll find:

* **Parameters** – every YAML `params` key, its default, and meaning.
* **Test cases** – the LAVA test-case IDs the module emits (sanitised form, see
  the [README](../README.md#test-case-id-conventions)).

To add a new module or test case, see
[`extending-tests.md`](extending-tests.md).

Conventions used below:

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

---

## audio (`adv-audio`)

Audio device checks. Enumeration via `aplay -l` / `arecord -l` is automated;
functional playback/recording requires a physical loopback cable and is a skip
stub.

**Prerequisites:** physical audio loopback cable for functional tests.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `AUDIO_PLAYBACK_COUNT` | `0` | Number of playback devices |
| `AUDIO_CAPTURE_COUNT` | `0` | Number of capture devices |
| `AUDIO_PB{N}_CARD` | `""` | Expected playback card name (from `aplay -l`) |
| `AUDIO_PB{N}_CONTROLLER` | `""` | Expected controller (card index prefix) |
| `AUDIO_PB{N}_DEV_ID` | `""` | Expected device sub-id |
| `AUDIO_PB{N}_CODEC` | `""` | Expected codec name |
| `AUDIO_CAP{N}_CARD` | `""` | Expected capture card name (from `arecord -l`) |
| `AUDIO_CAP{N}_CONTROLLER` | `""` | Expected controller |
| `AUDIO_CAP{N}_DEV_ID` | `""` | Expected device sub-id |
| `AUDIO_CAP{N}_CODEC` | `""` | Expected codec name |

**Test cases:**

* `L-AUDIO-PLAYBACK-DEV-pb{N}` – playback device enumerated and matches card/codec
* `L-AUDIO-RECORDING-DEV-cap{N}` – capture device enumerated and matches card/codec
* `L-AUDIO-PLAYBACK-F` – functional playback (skip stub)
* `L-AUDIO-RECORDING-F` – functional recording (skip stub)

---

## can (`adv-can`)

CAN bus checks: interface existence, bus controller, clock frequency, software
loopback (self-contained), and external peer-to-peer loopback (needs a physical
CAN cable).

**Prerequisites:** external loopback requires two CAN ports wired together.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CAN_COUNT` | `1` | Number of CAN interfaces |
| `CAN{N}_DEV` | `can0` | Interface name |
| `CAN{N}_BUS` | `soc` | Bus type (`soc` or `pci`) |
| `CAN{N}_BUS_ID` | `""` | Bus address/ID |
| `CAN{N}_CLOCK` | `""` | Expected clock in Hz (empty = skip) |
| `CAN{N}_LOOPBACK_SPEEDS` | `125000 500000` | Space-separated bitrates for SW loopback |
| `CAN_EXT_LOOPBACK` | `""` | Space-separated `<ifA>:<ifB>:<bitrate>` (empty = skip) |

**Test cases:**

* `L-CAN-DEV-${label}` – interface exists
* `L-CAN-CONTROLLER-${label}` – bus controller present
* `L-CAN-CLOCK-${label}` – clock frequency matches
* `L-CAN-LOOPBACK-F-${label}` – software loopback at configured speeds
* `L-CAN-EXT-LOOP-F` – external peer-to-peer loopback (skip when not configured)

---

## context (`adv-context`)

System context checks.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DISTRO_ID` | `yocto` | Expected distro ID (case-insensitive substring match) |
| `DISTRO_VER` | `""` | Expected distro version substring (empty = skip) |
| `KERNEL_MIN_VER` | `6.6` | Minimum kernel version |
| `CPU_MODEL` | `""` | Expected CPU model string (empty = skip) |
| `BIOS_DATE` | `""` | Expected BIOS date `YYYYMMDD` (empty = skip) |

**Test cases:**

* `L-SW-DISTRO-ID` – distro ID matches
* `L-SW-DISTRO-VER` – distro version matches
* `L-SW-KERNEL-MIN-VER` – running kernel ≥ minimum
* `L-CPU-MODEL` – CPU model matches
* `L-BIOS-DATE-MINIMUM` – BIOS date ≥ expected

---

## cpu (`adv-cpu`)

CPU checks: count, C-states, cpufreq scaling, governors, suspend states.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CPU_MODEL` | `Cortex-A35` | Expected CPU model string |
| `CPU_NPROC` | `4` | Expected CPU count (space-separated variants allowed, e.g. `2 4`) |
| `CPU_CSTATES` | `""` | Space-separated expected C-state names (empty = skip) |
| `CPU_SCALING_MIN` | `0` | Expected `scaling_min_freq` in kHz (0 = skip) |
| `CPU_SCALING_MAX` | `0` | Expected `scaling_max_freq` in kHz (0 = skip) |
| `CPU_SCALING_GOVERNORS` | `""` | Space-separated governor names to verify |
| `CPU_SUSPENSION_STATES` | `""` | Space-separated `/sys/power/state` values (e.g. `freeze mem`) |

**Test cases:**

* `L-CPU-NPROC` – number of online CPUs matches
* `L-CPU-C-STATES-${k}` – per C-state name present
* `L-CPU-FREQ-SCALING-MIN-${k}` / `L-CPU-FREQ-SCALING-MAX-${k}` – per-CPU min/max freq
* `L-CPU-SCALING-GOVERNOR-${k}` – governor available
* `L-CPU-SCALING-GOVERNOR-SET-F-${k}` – governor can be set (functional)
* `L-CPU-POWER-STATE-SUSPENSION` – supported suspend states match

---

## disk (`adv-disk`)

Disk checks: rootfs mount/mode, block device type/sector count, eMMC extended
CSD readability, and dd read/write throughput. Throughput tests are functional
and skipped when their minimum speed is 0.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DISK_COUNT` | `1` | Number of block devices to check |
| `DISK_ROOTFS_MOUNT` | `""` | Space-separated `<dev>:<mode>:<label>` entries (empty = skip) |
| `DISK{N}_DEV` | `/dev/mmcblk0` | Block device node |
| `DISK{N}_TYPE` | `MMC` | Expected type: `MMC`, `SD`, `USB`, `SATA`, `NVMe`, … |
| `DISK{N}_SECTORS` | `0` | Expected sector count (0 = skip) |
| `DISK{N}_MIN_RS` | `100` | Minimum read speed MB/s (0 = skip) |
| `DISK{N}_MIN_WS` | `40` | Minimum write speed MB/s (0 = skip) |

**Test cases:**

* `L-DISK-ROOTFS-FOUND` / `L-DISK-ROOTFS-MODE` – rootfs mount present and mounted with expected mode
* `L-DISK-DEV-disk{N}` – block device exists
* `L-DISK-TYPE-disk{N}` – device transport type matches
* `L-DISK-SECTORS-disk{N}` – sector count matches
* `L-DISK-EXTCSD-READABLE-disk{N}` – eMMC extended CSD readable
* `L-DISK-READ-THROUGHPUT-F-disk{N}` / `L-DISK-WRITE-THROUGHPUT-F-disk{N}` – dd throughput ≥ minimum

---

## eth (`adv-eth`)

Ethernet checks: device, bus controller, link speed, IPv4/IPv6 addresses,
Wake-on-LAN, DNS resolution, ping, and optional iperf3 TX/RX throughput.
Throughput tests are skipped when `IPERF3_SERVER_IP` is empty.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ETH_COUNT` | `1` | Number of Ethernet interfaces |
| `ETH{N}_DEV` | `eth0` | Interface name |
| `ETH{N}_BUS` | `soc` | Bus type |
| `ETH{N}_BUS_ID` | `29950000` | Bus address/ID |
| `ETH{N}_LINK` | `100` | Expected link speed in Mbps |
| `ETH{N}_WOL_FEATURED` | `""` | WoL capability char (e.g. `g`), empty = skip |
| `ETH{N}_WOL_WAKEUP` | `""` | Expected `/sys/…/wakeup` value (`enabled`/`disabled`) |
| `ETH{N}_MIN_TX_SPEED` | `90` | Minimum TX throughput MB/s (0 = skip) |
| `ETH{N}_MIN_RX_SPEED` | `90` | Minimum RX throughput MB/s (0 = skip) |
| `IPERF3_SERVER_IP` | `""` | Host-side iperf3 server IP (empty = skip throughput) |
| `IPERF3_DURATION` | `5` | iperf3 test duration in seconds |
| `DNS_CHECK_HOSTS` | `advantech.com google.com` | Space-separated hostnames |
| `PING_CHECK_HOSTS` | `advantech.com google.com` | Space-separated hostnames |

**Test cases:**

* `L-ETH-DEV-${label}` – interface exists
* `L-ETH-CONFIGURED-${label}` – interface configured/up
* `L-ETH-CONTROLLER-${label}` – bus controller present
* `L-ETH-LINK-${label}` – link speed matches
* `L-ETH-IPV4-ADDRESS-${label}` / `L-ETH-IPV6-ADDRESS-${label}` – address assigned
* `L-ETH-WAKEUP-FEATURED-${label}` / `L-ETH-WAKEUP-ENABLED-${label}` – WoL capability/state
* `L-DNS-IPV${proto}` – DNS resolution over IPv4/IPv6
* `L-ETH-IPV${proto}-PING` – ping connectivity
* `L-ETH-TX-THROUGHPUT-F-${label}` / `L-ETH-RX-THROUGHPUT-F-${label}` – iperf3 throughput ≥ minimum

---

## gpio (`adv-gpio`)

GPIO checks: device node, chip/controller label, line count, per-pin direction,
input read, output set high/low, and interrupt edge configuration.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GPIO_COUNT` | `1` | Number of GPIO chips |
| `GPIO{N}_DEV` | `/dev/gpiochip0` | Device node |
| `GPIO{N}_CHIP` | `gpiochip0` | sysfs chip name |
| `GPIO{N}_CONTROLLER` | `""` | Expected controller label (empty = skip) |
| `GPIO{N}_NLINES` | `0` | Expected line count (0 = skip) |
| `GPIO_PINS` | `""` | Space-separated `<chip_label>:<pin>:<direction[.edge]>:<label>` entries. `direction` = `in`\|`out`; `edge` = `rising`\|`falling`\|`both` (optional, for IRQ pins). Example: `GPIO0:5:in:SENSOR_IRQ GPIO0:6:out:LED_RED` |

**Test cases:**

* `L-GPIO-DEV-${label}` – gpiochip device node exists
* `L-GPIO-CHIP-${label}` – chip name matches
* `L-GPIO-CONTROLLER-${label}` – controller label matches
* `L-GPIO-LINES-${label}` – line count matches
* `L-GPIO-INPUT` / `L-GPIO-OUTPUT` – pin direction configured
* `L-GPIO-SENSED` – input pin read back
* `L-GPIO-SET-HIGH-LOW` – output pin set high then low
* `L-GPIO-INT-SOURCE` / `L-GPIO-INTERRUPT` – interrupt edge configured and triggered

---

## gpu (`adv-gpu`)

GPU checks: DRI/KMS device nodes, GL/GLES/EGL libraries, Wayland compositor,
Vulkan and VA-API detection, glmark2 validation, and DRM connector/LVDS/backlight
properties. Tests requiring an active display are skip stubs when tools/display
are absent.

**Prerequisites:** glmark2 needs a running Wayland/X11 compositor; VA-API needs
`vainfo`; Vulkan needs `vulkaninfo`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GPU_COUNT` | `1` | Number of GPU/display connectors |
| `GPU{N}_DRI_KMS_DEV` | `/dev/dri/card0` | DRI/KMS device node |
| `GPU{N}_BACKLIGHT_DEV` | `""` | `/sys/class/backlight/<dev>` (empty = skip) |
| `GPU{N}_LVDS_MOD` | `""` | Expected LVDS kernel module (empty = skip) |
| `GPU{N}_LVDS_DEV` | `""` | `/sys/devices/…/connector` path (empty = skip) |
| `GPU{N}_DRM_CONNECTOR` | `""` | modetest connector name (empty = skip) |
| `GPU{N}_DRM_CONNECTOR_ENCODER` | `""` | modetest encoder name (empty = skip) |
| `GPU{N}_RESOLUTION` | `""` | Expected resolution `WxH` (empty = skip) |
| `GPU{N}_REFRESH_RATE` | `""` | Expected refresh rate Hz (empty = skip) |
| `GPU_WAYLAND` | `""` | Compositor: `weston`, `mutter`, or empty to skip |
| `GPU_VA_CODECS` | `""` | Space-separated `codec:entry` pairs for vainfo |
| `SKIP_INSTALL` | `false` | Skip tool installation step |

**Test cases:**

* `L-GPU-DRI-KMS-DEV-gpu{N}` – DRI/KMS node exists
* `L-GPU-OPENGL-F` / `L-GPU-OPENGL-ES-F` – GL / GLES rendering (glmark2)
* `L-GPU-WAYLAND` – Wayland compositor running
* `L-GPU-VULKAN-DEV` – Vulkan device detected
* `L-GPU-VA-HW-FFMPEG` / `L-GPU-VA-HW-CODECS` – VA-API hardware and codecs
* `L-GPU-BACKLIGHT-DEV-gpu{N}` / `L-GPU-BACKLIGHT-F-gpu{N}` / `L-GPU-BACKLIGHT-RESTORE-F-gpu{N}` – backlight present, set, restored
* `L-GPU-DRM-CONNECTOR-gpu{N}` / `L-GPU-DRM-CONNECTOR-ENCODER-gpu{N}` – connector/encoder
* `L-GPU-DRM-CONNECTOR-RESOLUTION-gpu{N}` / `L-GPU-DRM-CONNECTOR-REFRESH-RATE-gpu{N}` – mode
* `L-GPU-DRM-LVDS-MODULE-gpu{N}` / `L-GPU-DRM-LVDS-DEV-gpu{N}` / `L-GPU-DRM-LVDS-ENABLED-gpu{N}` – LVDS

---

## i2c (`adv-i2c`)

I2C bus checks: device node existence, R/W access, and expected controller name
from `i2cdetect -l`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `I2C_COUNT` | `1` | Number of I2C buses |
| `I2C{N}_DEV` | `/dev/i2c-0` | Device node |
| `I2C{N}_CONTROLLER` | `""` | Expected controller name (from `i2cdetect -l`) |
| `I2C{N}_REFERENCE` | `""` | Human reference (informational only) |

**Test cases:**

* `L-I2C-DEV-i2c{N}` – device node exists and is R/W
* `L-I2C-CONTROLLER-i2c{N}` – controller name matches

---

## npu (`adv-npu`)

NPU device checks: device node R/W access and bus controller presence.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `NPU_COUNT` | `1` | Number of NPU devices |
| `NPU{N}_DEV` | `""` | Device node, e.g. `/dev/galcore` |
| `NPU{N}_BUS` | `soc` | Bus type (`soc` or `pci`) |
| `NPU{N}_BUS_ID` | `""` | Bus address/ID |
| `NPU{N}_BUS_DEVICE_TYPE` | `""` | Bus device type for soc sysfs lookup |
| `NPU{N}_BUS_NODE_NAME` | `""` | Node name for soc sysfs lookup |

**Test cases:**

* `L-NPU-DEV-npu{N}` – device node exists and is R/W
* `L-NPU-CONTROLLER-npu{N}` – bus controller present

---

## optee (`adv-optee`)

OP-TEE checks: TEE device node and the `xtest` regression suite. `xtest` runs in
quick mode by default.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `OPTEE_DEV` | `/dev/tee0` | TEE device node |
| `OPTEE_FULL_TEST` | `0` | `0` = quick xtest (skip suite 1001), `1` = full suite (slow) |

**Test cases:**

* `L-OPTEE-DEV` – TEE device node exists
* `L-OPTEE-XTEST-F` – xtest regression passes (skip when xtest absent)

---

## pwm (`adv-pwm`)

PWM checks: chip presence under `/sys/class/pwm/`, bus controller, and optional
backlight brightness.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PWM_COUNT` | `1` | Number of PWM chips |
| `PWM{N}_DEV` | `pwmchip0` | sysfs chip name |
| `PWM{N}_BUS` | `soc` | Bus type (`soc` or `pci`) |
| `PWM{N}_BUS_ID` | `""` | Bus address/ID |
| `PWM{N}_REFERENCE` | `""` | Human reference (informational only) |
| `PWM_BACKLIGHT_DEV` | `""` | `/sys/class/backlight/<dev>` path (empty = skip) |

**Test cases:**

* `L-PWM-DEV-pwm{N}` – PWM chip present
* `L-PWM-CONTROLLER-pwm{N}` – bus controller present
* `L-PWM-BACKLIGHT-BRIGHTNESS-DEV` – backlight brightness device present

---

## ram (`adv-ram`)

RAM checks: per-slot size (MB) and speed (MT/s) via dmidecode, minimum available
memory, and a memtester stability test on ~90% of free RAM.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RAM_SLOT_COUNT` | `1` | Number of RAM slots |
| `RAM_SLOT{N}_SIZE` | `1024` | Expected slot size in MB |
| `RAM_SLOT{N}_SPEED` | `""` | Expected slot speed in MT/s (empty = skip) |
| `RAM_MIN_AVAIL` | `800` | Minimum reported MemTotal in MiB |

**Test cases:**

* `L-RAM-SIZE-slot{N}` – slot size matches
* `L-RAM-SPEED-slot{N}` – slot speed matches
* `L-RAM-AVAILABLE-MIN` – MemTotal ≥ minimum
* `L-RAM-AVAILABLE-TOTAL` – reports MemTotal as a measurement (MiB)
* `L-RAM-STABILITY-F` – memtester stability run (skip when memtester absent)

---

## rtc (`adv-rtc` + `adv-rtc-suspend`)

`rtc.yaml` covers the non-disruptive subset (device node, hwclock get/set,
wakeup flag). The suspend/wakeup test is in `rtc-suspend.yaml` and **must run as
its own LAVA job** because it resets the board's power state.

### rtc.yaml

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RTC_COUNT` | `1` | Number of RTC devices |
| `RTC{N}_DEV` | `/dev/rtc0` | Device node |
| `RTC{N}_WAKEUP` | `enabled` | Expected `/sys/…/wakeup` value (`enabled`/`disabled`) |

**Test cases:**

* `L-RTC-DEFAULT` – default RTC present
* `L-RTC-DEV-rtc{N}` – device node exists
* `L-RTC-GET-F-rtc{N}` / `L-RTC-SET-F-rtc{N}` – hwclock read/write
* `L-RTC-WAKEUP-rtc{N}` – wakeup flag matches

### rtc-suspend.yaml

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RTC_DEV` | `/dev/rtc0` | Device node |
| `SLEEP_STATE` | `mem` | `rtcwake -m` argument: `mem`, `freeze`, `standby`, … |
| `WAKE_SLEEP_TIME_S` | `5` | Seconds to sleep before waking |

**Test cases:**

* `L-SUSPEND-WAKEUP-F-rtc0` – board suspends and resumes after the expected delay

---

## spi (`adv-spi`)

SPI device checks: node existence, R/W access, and `spidev_test` loopback.

**Prerequisites:** physical SPI loopback (MOSI–MISO) for `spidev_test`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `SPI_COUNT` | `1` | Number of SPI devices |
| `SPI{N}_DEV` | `/dev/spidev0.0` | Device node |

**Test cases:**

* `L-SPI-DEV-spi{N}` – device node exists and is R/W
* `L-SPI-DEV-TEST-F-spi{N}` – spidev_test loopback passes

---

## thermal (`adv-thermal`)

Thermal zone checks: sysfs path existence and current temperature within
MIN/MAX bounds.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `THERMAL_COUNT` | `1` | Number of thermal zones |
| `TZ{N}_DEV` | `thermal_zone0` | sysfs name under `/sys/class/thermal/` |
| `TZ{N}_MIN` | `10` | Minimum expected temperature (°C) |
| `TZ{N}_MAX` | `95` | Maximum expected temperature (°C) |

**Test cases:**

* `L-THERMAL-ZONE-DEV-tz{N}` – thermal zone exists
* `L-THERMAL-ZONE-TEMP-tz{N}` – current temperature (measurement)
* `L-THERMAL-ZONE-MIN-tz{N}` / `L-THERMAL-ZONE-MAX-tz{N}` – temperature within bounds

---

## tpm (`adv-tpm`)

TPM checks: device node, self-test, manufacturer ID, capabilities, and PCR
readability. Supports TPM 1.x (tpm-tools) and TPM 2.0 (tpm2-tools).

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TPM_COUNT` | `1` | Number of TPM devices |
| `TPM{N}_DEV` | `/dev/tpm0` | Device node |
| `TPM{N}_VERSION` | `2` | TPM major version: `1` or `2` |
| `TPM{N}_MANUF1` | `""` | Expected `TPM2_PT_VENDOR_STRING_1` (empty = skip) |
| `TPM{N}_MANUF2` | `""` | Expected `TPM2_PT_VENDOR_STRING_2` (empty = skip) |
| `TPM{N}_CAPS` | `""` | Space-separated capability names to verify (TPM 2.0 only) |

**Test cases:**

* `L-TPM-DEV-${label}` – device node exists
* `L-TPM-SELF-TEST-F-${label}` – self-test passes
* `L-TPM-CONTROLLER-${label}` – manufacturer ID matches
* `L-TPM-CAPABILITIES-${label}` – capabilities present
* `L-TPM-PCR-READABLE-F-${label}` – PCR banks readable

---

## uart (`adv-uart`)

UART checks: device node, bus controller, stty configuration, optional HWFC,
debug-console flag, and loopback functional tests.

**Prerequisites:** physical UART loopback cable for `L-UART-LOOPBACK-F` tests.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `UART_COUNT` | `1` | Number of UART ports |
| `UART{N}_DEV` | `/dev/ttyLP0` | Device node |
| `UART{N}_BUS` | `soc` | Bus type |
| `UART{N}_BUS_ID` | `""` | Bus address/ID |
| `UART{N}_HWFC` | `0` | `1` = hardware flow control expected |
| `UART{N}_DEBUG_CONSOLE` | `0` | `1` = port is the kernel debug console |
| `UART{N}_LOOPBACK_TEST` | `skip` | `skip` or space-separated `<baud>:<2W\|4W>` entries |
| `UART{N}_REFERENCE` | `""` | Human reference (informational only) |

**Test cases:**

* `L-UART-DEV-${label}` – device node exists
* `L-UART-CONTROLLER-${label}` – bus controller present
* `L-UART-CONFIGURE-F-${label}` – stty configuration applied
* `L-UART-HWFC-${label}` – hardware flow control state matches
* `L-UART-DEBUG-CONSOLE-${label}` – debug console flag matches
* `L-UART-LOOPBACK-F-${label}` – loopback at configured baud/wiring (skip when not configured)

---

## usb (`adv-usb`)

USB host and OTG checks: host-bus enumeration, optional specific plugged-device
checks (port/driver/speed), and USB OTG kernel config + gadget driver.

**Prerequisites:** plugged-device tests require specific USB devices connected.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `USB_DEV_COUNT` | `0` | Number of specific plugged devices to check (0 = skip) |
| `USB_DEV{N}_PORT` | `""` | USB port number (`lsusb -t`) |
| `USB_DEV{N}_DRIVER` | `""` | Expected driver name |
| `USB_DEV{N}_SPEED` | `""` | Expected speed, e.g. `480M` |
| `USB_OTG_ENABLED` | `0` | `1` = check OTG gadget support |
| `USB_OTG_CONF` | `""` | Space-separated kernel config keys (from `/proc/config.gz`) |

**Test cases:**

* `L-USB-HOST-DEV` – at least one device enumerated on the host bus
* `L-USB-PLUGGED-DEV-F-dev{N}` – specific plugged device matches port/driver/speed
* `L-USB-OTG-CONF-${cfg_key}` – OTG kernel config key enabled
* `L-USB-OTG-ETH-F` – OTG ethernet gadget functional (skip stub)

---

## watchdog (`adv-watchdog` + `adv-watchdog-reboot`)

`watchdog.yaml` covers the non-disruptive subset (device node, daemon running).
The reboot test is in `watchdog-reboot.yaml` and **must run as its own LAVA
job** because it deliberately triggers a hardware reboot.

### watchdog.yaml

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WATCHDOG_COUNT` | `1` | Number of watchdog devices |
| `WATCHDOG{N}_DEV` | `/dev/watchdog0` | Device node |

**Test cases:**

* `L-WATCHDOG-DEV-watchdog{N}` – device node exists
* `L-WATCHDOG-SERVICE` – watchdog daemon running

### watchdog-reboot.yaml

The job's `auto_login` action must handle the reboot and re-login before the
result file is read.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WATCHDOG_DEV` | `/dev/watchdog0` | Device node |
| `WATCHDOG_TIMEOUT_S` | `30` | Seconds to wait for the reboot to complete |

**Test cases:**

* `L-WATCHDOG-REBOOT-F` – withholding keepalive fires the watchdog and reboots the board

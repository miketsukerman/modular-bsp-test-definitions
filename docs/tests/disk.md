# disk (`adv-disk`)

Disk checks: root filesystem mount point/mode, block device presence and type,
sector count, eMMC extended CSD readability, and read/write throughput using
`dd`.

* **Definition:** [`automated/linux/disk/disk.yaml`](../../automated/linux/disk/disk.yaml)
* **Script:** [`automated/linux/disk/disk.sh`](../../automated/linux/disk/disk.sh)

## Scope

**Covered**

* Optional root filesystem device and mount-mode validation.
* Each configured block device exists, is readable/writable, and can be listed
  by `fdisk`.
* Expected sector count from `/sys/block/<dev>/size` when configured.
* Disk transport/type as reported by the shared `disk_type` helper.
* eMMC extended CSD readability for disks whose expected type is `MMC`.
* Optional read and write throughput measurements, reported in `MB/s`.

**Not covered**

* Destructive media testing or full-device write/read verification.
* Filesystem consistency checks.
* Electrical or signal-integrity validation of removable media.

## Prerequisites

* **Hardware:** configured disks must be present. Write throughput needs a
  writable mountable partition on the tested disk; otherwise that case is
  skipped.
* **Target tools:** `fdisk`, `lsblk`, `dd`, `awk`, `mount`, `umount`; `mmc` is
  needed for the eMMC extended CSD check and is skipped if absent.
* **Root:** required. The script reads block devices, mounts partitions, and
  writes `/proc/sys/vm/drop_caches`.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DISK_COUNT` | `"1"` | Number of disks to iterate over (`disk0` … `disk<COUNT-1>`) |
| `DISK_ROOTFS_MOUNT` | `""` | Space-separated `<dev>:<mode>:<label>` entries. Empty = rootfs checks not emitted |
| `DISK{N}_DEV` | `/dev/mmcblk0` | Block device node for disk `N` |
| `DISK{N}_TYPE` | `"MMC"` | Expected disk type (`MMC`, `SD`, `USB`, `SATA`, `NVMe`, …) |
| `DISK{N}_SECTORS` | `"0"` | Expected sector count; `0` = check not emitted |
| `DISK{N}_MIN_RS` | `"100"` | Minimum read speed in `MB/s`; `0` = check not emitted |
| `DISK{N}_MIN_WS` | `"40"` | Minimum write speed in `MB/s`; `0` = check not emitted |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

Only `DISK{N}_DEV` is mandatory per disk; missing or empty optional thresholds
remove the corresponding checks from the results.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `disk<N>` for disk `N`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-DISK-ROOTFS-MODE` | | Root filesystem device matches an entry and mount mode equals the configured mode | Rootfs device matches, but mount mode differs | Not emitted when `DISK_ROOTFS_MOUNT` is empty |
| `L-DISK-ROOTFS-FOUND` | | Root filesystem device is listed in `DISK_ROOTFS_MOUNT` | Rootfs device is not listed | Not emitted when `DISK_ROOTFS_MOUNT` is empty |
| `L-DISK-DEV-${label}` | | Device exists, is a block device, is readable/writable, and `fdisk -l` succeeds | Device exists but is not readable/writable as a block device (remaining checks for this disk are abandoned) | Not emitted when the device is missing or `fdisk -l` fails |
| `L-DISK-SECTORS-${label}` | | `/sys/block/<dev>/size` equals `DISK{N}_SECTORS` | Sector count differs | Not emitted when `DISK{N}_SECTORS` is `0` |
| `L-DISK-TYPE-${label}` | | Detected disk type equals `DISK{N}_TYPE` | Detected type differs | Only after `L-DISK-DEV-${label}` passes |
| `L-DISK-EXTCSD-READABLE-${label}` | | `mmc extcsd read <dev>` succeeds | `mmc extcsd read` fails | Skip when `mmc` is missing; not emitted unless `DISK{N}_TYPE` is `MMC` |
| `L-DISK-READ-THROUGHPUT-F-${label}` | ✓ | `dd` read speed is at least `DISK{N}_MIN_RS`; reports metric in `MB/s` | Measured read speed is below the threshold or unparsable; reports metric in `MB/s` | Not emitted when `DISK{N}_MIN_RS` is `0` |
| `L-DISK-WRITE-THROUGHPUT-F-${label}` | ✓ | `dd` write speed is at least `DISK{N}_MIN_WS`; reports metric in `MB/s` | Measured write speed is below the threshold or unparsable; reports metric in `MB/s` | Skip when no writable partition can be mounted; not emitted when `DISK{N}_MIN_WS` is `0` |

The throughput checks use `report_metric`, so LAVA receives the integer
measurement and `MB/s` units alongside the pass/fail result.

## Running locally

```sh
cd automated/linux/disk
DISK_COUNT=1 \
DISK_ROOTFS_MOUNT="/dev/mmcblk0p2:rw:rootfs" \
DISK0_DEV=/dev/mmcblk0 \
DISK0_TYPE=MMC \
DISK0_SECTORS=0 \
DISK0_MIN_RS=100 \
DISK0_MIN_WS=40 \
bash disk.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for device,
sector, type, eMMC extended CSD and throughput checks, including `fdisk` output
for `L-DISK-DEV-*`, and each log ends in a `RESULT:` line. LAVA surfaces these
logs alongside the test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-DISK-DEV-*` missing | Device node is absent, not a block device, or `fdisk -l` cannot read it |
| `L-DISK-DEV-*` fails | The test is not running as root, or the block device is not readable/writable |
| `L-DISK-TYPE-*` fails | Expected type does not match sysfs/`lsblk` transport (`MMC`, `SD`, `USB`, …) |
| `L-DISK-EXTCSD-READABLE-*` skips | `mmc` from mmc-utils is not installed on the target |
| `L-DISK-WRITE-THROUGHPUT-F-*` skips | No writable partition on the configured disk can be mounted |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_DISK` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

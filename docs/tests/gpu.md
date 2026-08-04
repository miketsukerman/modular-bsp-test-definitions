# gpu (`adv-gpu`)

GPU/display checks: GL/GLES/EGL library presence, optional Wayland compositor,
`glmark2` validation, Vulkan and VA-API detection, DRI/KMS nodes, LVDS/DRM
connector properties, resolution/refresh rate, and backlight behaviour.

* **Definition:** [`automated/linux/gpu/gpu.yaml`](../../automated/linux/gpu/gpu.yaml)
* **Script:** [`automated/linux/gpu/gpu.sh`](../../automated/linux/gpu/gpu.sh)

## Scope

**Covered**

* OpenGL, EGL and GLES library presence via `ldconfig`.
* Optional Wayland compositor process/service check.
* `glmark2` and `glmark2-es2` validation when the commands are installed.
* Vulkan device discovery, VA-API ffmpeg support, and configured VA codec
  entries.
* Per-display DRI/KMS character device, optional LVDS module/sysfs state, DRM
  connector/encoder, monitor resolution and refresh rate.
* Optional backlight device sanity check, brightness sweep, and restore.

**Not covered**

* GPU performance scoring; `glmark2` is run only with `--validate`.
* Visual inspection of the display output.
* Multi-monitor layout, hotplug, color, audio-over-HDMI or suspend/resume.

## Prerequisites

* **Hardware:** configured display/GPU devices must be present. `glmark2` checks
  need a running Wayland or X11 display session, and backlight checks need a
  writable backlight sysfs device.
* **Target tools:** `ldconfig`, `glmark2`/`glmark2-wayland`,
  `glmark2-es2`/`glmark2-es2-wayland`, `vulkaninfo`, `ffmpeg`, `vainfo`,
  `lsmod`, `modetest`, `hwinfo`; checks depending on optional tools are skipped
  or not emitted as described below.
* **Root:** often required for `/dev/dri/*` and backlight sysfs write access;
  exact requirements depend on target permissions.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GPU_COUNT` | `"1"` | Number of GPU/display instances to iterate over (`gpu0` … `gpu<COUNT-1>`) |
| `GPU{N}_DRI_KMS_DEV` | `/dev/dri/card0` | DRI/KMS character device for instance `N`; empty = check not emitted |
| `GPU{N}_BACKLIGHT_DEV` | `""` | Backlight sysfs path, such as `/sys/class/backlight/<dev>`; empty = backlight checks not emitted |
| `GPU{N}_LVDS_MOD` | `""` | Expected LVDS kernel module; empty = module check not emitted |
| `GPU{N}_LVDS_DEV` | `""` | LVDS connector sysfs path; empty = LVDS device/enabled checks not emitted |
| `GPU{N}_DRM_CONNECTOR` | `""` | Connector name searched in `modetest -c`; empty = connector checks not emitted |
| `GPU{N}_DRM_CONNECTOR_ENCODER` | `""` | Encoder name searched in `modetest -e`; empty = encoder check not emitted |
| `GPU{N}_RESOLUTION` | `""` | Expected monitor resolution `WxH`; empty = resolution check not emitted |
| `GPU{N}_REFRESH_RATE` | `""` | Expected refresh rate in Hz; empty = refresh-rate check not emitted |
| `GPU_WAYLAND` | `""` | Compositor name (`weston`, `mutter`, or empty). Also selects Wayland `glmark2` commands |
| `GPU_VA_CODECS` | `""` | Space-separated `codec:entry` pairs to look for in `vainfo`; empty = codec checks not emitted |
| `SKIP_INSTALL` | `"false"` | Defined by the YAML but not used by `gpu.sh` |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

Only `GPU{N}_DRI_KMS_DEV` is populated by default; every other per-instance key
is optional and its absence removes the corresponding checks from the results.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `gpu<N>` for instance
`N`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-GPU-OPENGL-F` | ✓ | `libGL.so` is present; later, `glmark2`/`glmark2-wayland --validate` succeeds | `libGL.so` is absent, or validation command fails | Validation result is skipped when the selected `glmark2` command is missing |
| `L-GPU-OPENGL-ES-F` | ✓ | `libEGL.so` and `libGLESv2.so` are present; later, `glmark2-es2`/`glmark2-es2-wayland --validate` succeeds | Either library is absent, or validation command fails | Validation result is skipped when the selected `glmark2-es2` command is missing |
| `L-GPU-WAYLAND` | | Configured `weston` service or `mutter` process is running | Configured compositor is not detected or name is unsupported | Not emitted when `GPU_WAYLAND` is empty |
| `L-GPU-VULKAN-DEV` | | `vulkaninfo` reports a `GPU id` line | `vulkaninfo` runs but no GPU line is found | Skip when `vulkaninfo` is missing |
| `L-GPU-VA-HW-FFMPEG` | | `ffmpeg -hwaccels` lists `vaapi` | `ffmpeg` is present but does not list `vaapi` | Skip when `ffmpeg` is missing |
| `L-GPU-VA-HW-CODECS` | | Each configured `codec:entry` pair is found in `vainfo` output | A configured pair is not found | Not emitted when `GPU_VA_CODECS` is empty or `vainfo` is missing |
| `L-GPU-DRI-KMS-DEV-${label}` | | Device exists and is a readable/writable char device | Node missing or not R/W | Not emitted when `GPU{N}_DRI_KMS_DEV` is empty |
| `L-GPU-DRM-LVDS-MODULE-${label}` | | `lsmod` contains `GPU{N}_LVDS_MOD` | Module is not loaded | Not emitted when `GPU{N}_LVDS_MOD` is empty |
| `L-GPU-DRM-LVDS-DEV-${label}` | | `<LVDS_DEV>/device` exists | Device path is missing | Not emitted when `GPU{N}_LVDS_DEV` is empty |
| `L-GPU-DRM-LVDS-ENABLED-${label}` | | `<LVDS_DEV>/enabled` reads `enabled` | Value differs or is unreadable | Not emitted when `GPU{N}_LVDS_DEV` is empty |
| `L-GPU-DRM-CONNECTOR-${label}` | | `modetest -c` finds a positive connector id for `GPU{N}_DRM_CONNECTOR` | Connector id is missing or not positive | Not emitted when connector is empty or `modetest` is missing |
| `L-GPU-DRM-CONNECTOR-ENCODER-${label}` | | `modetest -e` lists `GPU{N}_DRM_CONNECTOR_ENCODER` | Encoder is not listed | Not emitted when encoder is empty, connector check is not emitted, or `modetest` is missing |
| `L-GPU-DRM-CONNECTOR-RESOLUTION-${label}` | | `hwinfo --monitor` resolution equals `GPU{N}_RESOLUTION` | Resolution differs or is unreadable | Not emitted when resolution is empty or `hwinfo` is missing |
| `L-GPU-DRM-CONNECTOR-REFRESH-RATE-${label}` | | `hwinfo --monitor` refresh rate equals `GPU{N}_REFRESH_RATE` | Refresh rate differs or is unreadable | Not emitted when refresh rate is empty or `hwinfo` is missing |
| `L-GPU-BACKLIGHT-DEV-${label}` | | `<BACKLIGHT_DEV>/device` exists | Device path is missing (remaining backlight checks for this instance are abandoned) | Not emitted when `GPU{N}_BACKLIGHT_DEV` is empty |
| `L-GPU-BACKLIGHT-F-${label}` | ✓ | Current brightness is numeric, within `0..max_brightness`, and max is greater than zero | Brightness values are invalid | Only after `L-GPU-BACKLIGHT-DEV-${label}` passes |
| `L-GPU-BACKLIGHT-RESTORE-F-${label}` | ✓ | Brightness is restored to its original value after a sweep | Restored brightness differs | Only after `L-GPU-BACKLIGHT-F-${label}` passes |

`L-GPU-OPENGL-F` and `L-GPU-OPENGL-ES-F` can appear multiple times because the
script reports both library checks and `glmark2` validation under those IDs.

## Running locally

```sh
cd automated/linux/gpu
GPU_COUNT=1 \
GPU0_DRI_KMS_DEV=/dev/dri/card0 \
GPU0_DRM_CONNECTOR=LVDS-1 \
GPU0_RESOLUTION=1024x768 \
GPU0_REFRESH_RATE=60 \
GPU_WAYLAND=weston \
GPU_VA_CODECS="VAProfileH264Main:VAEntrypointVLD" \
bash gpu.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for library,
Wayland, Vulkan, VA-API, DRI/KMS, LVDS, DRM connector, resolution, refresh-rate
and backlight checks. `glmark2` validation output is written to
`output/glmark2_gl.log` and `output/glmark2_gl_es.log`. LAVA surfaces the
per-test-case logs alongside the test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-GPU-OPENGL-F` or `L-GPU-OPENGL-ES-F` skips | The matching `glmark2` command is missing for the selected X11/Wayland mode |
| `L-GPU-WAYLAND` fails | `GPU_WAYLAND` names a compositor that is not running, or only `weston`/`mutter` is supported |
| `L-GPU-VULKAN-DEV` skips | `vulkaninfo` is not installed on the target |
| `L-GPU-DRM-CONNECTOR-*` missing | `GPU{N}_DRM_CONNECTOR` is empty or `modetest` is not installed |
| `L-GPU-BACKLIGHT-F-*` fails | Backlight sysfs files are unreadable, `max_brightness` is zero, or permissions prevent writes |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_GPU` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

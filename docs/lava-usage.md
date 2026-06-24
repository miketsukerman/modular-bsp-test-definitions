# Using the test definitions with LAVA

This guide shows how to assemble the modular BSP test definitions into a
complete [LAVA](https://www.lavasoftware.org/) job. It assumes you already have
a working LAVA instance with your board defined as a device-type and at least
one device of that type online.

For the per-module parameter reference see
[`test-reference.md`](test-reference.md). For how an individual module executes
on the target see the [README](../README.md#how-a-module-runs).

## How the pieces fit together

A LAVA job is a YAML file describing a sequence of **actions**. To run these
tests you need three actions:

1. **`deploy`** – writes the test image onto the board (or stages it for a
   flasher).
2. **`boot`** – boots the target, logs in, and — crucially — uses
   `transfer_overlay` so LAVA can push the test overlay (which contains a
   checkout of this repository plus the LAVA helper scripts) onto the running
   system.
3. **`test`** – runs one or more **test definitions**. Each entry points at a
   module YAML in this repo (`automated/linux/<module>/<module>.yaml`) and
   supplies the board-specific `parameters` that override the YAML defaults.

Each `test` definition entry maps 1:1 to a module in this repository. LAVA
clones the listed `repository`, checks out the requested `branch`, runs the
module's `run.steps`, and the module emits one `lava-test-case` per check via
`utils/send-to-lava.sh`.

## Parameters override YAML defaults

Every module YAML ships with a `params:` block of sensible defaults. The
`parameters:` map on a `test` definition entry overrides those defaults for the
specific board. LAVA exports each key as an environment variable, which the
module script reads at runtime.

For example, `thermal.yaml` defaults `TZ0_MAX` to `95`. The job below tightens
it to `60` for this board simply by listing `TZ0_MAX: 60` under `parameters`.
Keys you don't override keep their YAML default.

> **Quote values that aren't plain integers.** Strings with spaces, pipes (`|`),
> or that should stay empty must be quoted, e.g.
> `CPU_SCALING_GOVERNORS: "performance powersave"`,
> `DISTRO_VER: "scarthgap|styhead|walnascar"`, `BIOS_DATE: ""`.

## The `transfer_overlay` requirement

The test definitions are *not* baked into the image — LAVA delivers them at
runtime as an overlay. The `boot` action must therefore declare
`transfer_overlay` with commands the target can use to download and unpack it:

```yaml
- boot:
    timeout:
      minutes: 10
    method: minimal
    transfer_overlay:
      download_command: cd /tmp && sleep 10 && wget
      unpack_command: tar -C / -xzf
    auto_login:
      login_prompt: "rom2820-ed93 login:"
      username: root
    prompts:
      - "root@rom2820-ed93:.*#"
```

This means the target image must provide `wget` (or `curl`) and `tar`, and have
network connectivity back to the LAVA dispatcher. Without `transfer_overlay` the
modules' `run.steps` (e.g. `cd ./automated/linux/thermal`) have nothing to run.

## Disruptive tests belong in their own jobs

`rtc-suspend` and `watchdog-reboot` change the board's power state
(suspend/resume or reboot) and will disrupt any other test still running in the
same job. Put each of them in a **separate** job definition with its own
`deploy`/`boot`/`test` sequence rather than appending them to a smoke-test job.

## Complete job example

The job below deploys an image via a flasher, boots and logs in, runs the
upstream Linaro smoke test, and then runs the `thermal`, `cpu`, `context`, and
`disk` modules from this repository with board-specific parameters.

```yaml
device_type: rom2820-ed93
job_name: rom2820-ed93-scarthgap-mbsp-test
priority: high
visibility: public

timeouts:
  job:
    minutes: 20
  action:
    minutes: 10
  connection:
    minutes: 2

actions:
  - deploy:
      to: flasher
      images:
        test_image:
          url: "http://192.168.3.180:8000/imx-image-core-rom2820-ed93.rootfs.wic.zst"

  - boot:
      timeout:
        minutes: 10
      method: minimal
      transfer_overlay:
        download_command: cd /tmp && sleep 10 && wget
        unpack_command: tar -C / -xzf
      auto_login:
        login_prompt: "rom2820-ed93 login:"
        username: root
      prompts:
        - "root@rom2820-ed93:.*#"

  - test:
      timeout:
        minutes: 10
      definitions:
        - repository: https://github.com/Linaro/test-definitions.git
          from: git
          path: automated/linux/smoke/smoke.yaml
          name: smoke

        - repository: https://github.com/miketsukerman/modular-bsp-test-definitions.git
          from: git
          branch: feature/add-modular-bsp-tests
          path: automated/linux/thermal/thermal.yaml
          name: adv-thermal
          parameters:
            THERMAL_COUNT: 1
            TZ0_DEV: thermal_zone0
            TZ0_MIN: 10
            TZ0_MAX: 60

        - repository: https://github.com/miketsukerman/modular-bsp-test-definitions.git
          from: git
          branch: feature/add-modular-bsp-tests
          path: automated/linux/cpu/cpu.yaml
          name: adv-cpu
          parameters:
            CPU_MODEL: Cortex-A55
            CPU_NPROC: 2
            CPU_CSTATES: ""
            CPU_SCALING_MIN: 1200000
            CPU_SCALING_MAX: 1600000
            CPU_SCALING_GOVERNORS: "performance powersave"
            CPU_SUSPENSION_STATES: "freeze mem"

        - repository: https://github.com/miketsukerman/modular-bsp-test-definitions.git
          from: git
          branch: feature/add-modular-bsp-tests
          path: automated/linux/context/context.yaml
          name: adv-context
          parameters:
            DISTRO_ID: Yocto
            DISTRO_VER: "scarthgap|styhead|walnascar"
            KERNEL_MIN_VER: 6.6
            CPU_MODEL: Cortex-A55
            BIOS_DATE: ""

        - repository: https://github.com/miketsukerman/modular-bsp-test-definitions.git
          from: git
          branch: feature/add-modular-bsp-tests
          path: automated/linux/disk/disk.yaml
          name: adv-disk
          parameters:
            DISK_COUNT: 3
            DISK_ROOTFS_MOUNT: "/dev/mmcblk0p2:rw:MMC /dev/mmcblk1p2:rw:SD"
            DISK0_DEV: /dev/mmcblk0
            DISK0_TYPE: MMC
            DISK0_SECTORS: 30777344
            DISK0_MIN_RS: 100
            DISK0_MIN_WS: 50
            DISK1_DEV: /dev/mmcblk1
            DISK1_TYPE: SD
            DISK1_SECTORS: 0
            DISK1_MIN_RS: 50
            DISK1_MIN_WS: 30
            DISK2_DEV: /dev/sda
            DISK2_TYPE: USB
            DISK2_SECTORS: 0
            DISK2_MIN_RS: 20
            DISK2_MIN_WS: 10
```

### Walkthrough

| Block | Purpose |
|-------|---------|
| `device_type` / `job_name` | Which device-type LAVA schedules on, and a human-readable job label. |
| `timeouts` | Caps for the whole job, each action, and the serial/SSH connection. Keep the `job` timeout above the sum of action timeouts. |
| `deploy: to: flasher` | Hands the `.wic.zst` image URL to the board's flasher. Adjust `to:` and `images:` to match how your device-type is provisioned. |
| `boot` | Boots with `auto_login`, matches the shell `prompts`, and pulls in the test overlay via `transfer_overlay`. The `login_prompt` and `prompts` regexes must match your board's hostname. |
| `test.definitions[0]` | The upstream Linaro `smoke` test — a quick sanity baseline. Optional but recommended. |
| `test.definitions[1..]` | One entry per module from this repo, each overriding the YAML defaults with board-specific `parameters`. |

### Adapting the example to your board

1. Set `device_type`, the `login_prompt`, and the shell `prompts` to your
   board's hostname.
2. Point `deploy.images.test_image.url` at your image and set `to:` to the
   deploy method your device-type uses.
3. Pin `branch:` to the ref you want to test (here
   `feature/add-modular-bsp-tests`; use `main` or a tag for stable runs).
4. Add or remove module entries under `definitions`, and fill in each module's
   `parameters` from your board's values — see
   [`test-reference.md`](test-reference.md) for every key, or generate them
   automatically with
   [`tools/conf_to_yaml.py`](../README.md#generating-board-parameters-toolsconf_to_yamlpy).

## Reading the results

Each module emits LAVA test cases named after the IDs in
[`test-reference.md`](test-reference.md) (sanitised form, e.g.
`L-CPU-NPROC`, `L-THERMAL-TEMP-tz0`). They appear under their definition `name`
(`adv-thermal`, `adv-cpu`, …) in the LAVA job results. Functional (`:F`) cases
report **skip** when their hardware prerequisites or parameters are absent, so a
clean run can legitimately contain skips.

# tpm (`adv-tpm`)

TPM checks: configured TPM device-node presence, self-test, TPM 2.0 vendor
string, TPM 2.0 capability list, and TPM 2.0 PCR readability.

* **Definition:** [`automated/linux/tpm/tpm.yaml`](../../automated/linux/tpm/tpm.yaml)
* **Script:** [`automated/linux/tpm/tpm.sh`](../../automated/linux/tpm/tpm.sh)

## Scope

**Covered**

* `/dev/tpmN` exists and is a readable/writable character device.
* TPM 1.x self-test via `tpm_selftest -f`, or TPM 2.0 self-test via
  `tpm2_selftest -f`.
* TPM 2.0 vendor string comparison using `TPM2_PT_VENDOR_STRING_1` and
  `TPM2_PT_VENDOR_STRING_2` when `TPM{N}_MANUF1` is set.
* TPM 2.0 capability names reported by `tpm2_getcap -l`.
* TPM 2.0 PCR output contains PCR bank `0:`.

**Not covered**

* TPM provisioning, ownership, sealing/unsealing, key persistence, attestation,
  or PCR value comparison.
* TPM 1.x manufacturer, capability, or PCR checks; the script only performs the
  TPM 1.x self-test after the device-node check.

## Prerequisites

* **Hardware:** a TPM exposed as a Linux character device such as `/dev/tpm0`.
* **Target tools:** `tpm_selftest` for TPM 1.x; `tpm2_selftest`, `tpm2_getcap`,
  and `tpm2_pcrread` for TPM 2.0 checks. Missing tools cause the relevant test
  cases to be skipped or not emitted as described below.
* **Root:** required when the TPM character device is not accessible to the test
  user.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TPM_COUNT` | `"1"` | Number of TPM devices to iterate over (`tpm0` … `tpm<COUNT-1>`) |
| `TPM{N}_DEV` | `/dev/tpm0` | Character device node for TPM `N` |
| `TPM{N}_VERSION` | `"2"` | TPM major version: `1` uses `tpm_selftest`; any other value uses TPM 2.0 tools |
| `TPM{N}_MANUF1` | `""` | Expected `TPM2_PT_VENDOR_STRING_1`; empty = manufacturer check not emitted |
| `TPM{N}_MANUF2` | `""` | Expected `TPM2_PT_VENDOR_STRING_2`; compared with `MANUF1` when `MANUF1` is non-empty |
| `TPM{N}_CAPS` | `""` | Space-separated TPM 2.0 capability names to verify |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

`TPM{N}_DEV` is mandatory for each configured TPM. If the device-node check
fails, all remaining checks for that TPM are not emitted.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `tpm<N>` for TPM `N`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-TPM-DEV-${label}` | | Device node exists and is a read/writable char device | Node missing or not R/W (remaining checks for this TPM are abandoned) | — |
| `L-TPM-SELF-TEST-F-${label}` | ✓ | `tpm_selftest -f` or `tpm2_selftest -f` exits 0 | Self-test command exits non-zero | `skip` when the selected self-test tool is missing; not emitted when the device-node check failed |
| `L-TPM-CONTROLLER-${label}` | | Concatenated TPM 2.0 vendor strings equal `TPM{N}_MANUF1``TPM{N}_MANUF2` | Vendor string differs | Not emitted for TPM 1.x, when `TPM{N}_MANUF1` is empty, when `tpm2_getcap` is missing, or when the device-node check failed |
| `L-TPM-CAPABILITIES-${label}` | | A configured capability appears in `tpm2_getcap -l` output | Capability is absent | `skip` when `tpm2_getcap` is missing; not emitted for TPM 1.x, when `TPM{N}_CAPS` is empty, or when the device-node check failed |
| `L-TPM-PCR-READABLE-F-${label}` | ✓ | `tpm2_pcrread` output contains a `0:` PCR bank | PCR output does not contain `0:` | `skip` when `tpm2_pcrread` is missing; not emitted for TPM 1.x or when the device-node check failed |

`L-TPM-CAPABILITIES-*` is emitted once per configured capability, reusing the
same test-case ID for each capability entry.

## Running locally

```sh
cd automated/linux/tpm
TPM_COUNT=1 \
TPM0_DEV=/dev/tpm0 \
TPM0_VERSION=2 \
TPM0_MANUF1=IFX \
TPM0_MANUF2="" \
TPM0_CAPS="properties-fixed algorithms" \
bash tpm.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for TPM device,
self-test, vendor, capability, and PCR checks that call `verbose_log` or
`verbose_cmd`. Vendor checks include raw `tpm2_getcap properties-fixed` output;
PCR checks include raw `tpm2_pcrread` output. LAVA surfaces these logs alongside
the test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-TPM-DEV-*` fails | Wrong TPM node, TPM driver missing, or insufficient permissions |
| `L-TPM-SELF-TEST-F-*` skips | `tpm_selftest` or `tpm2_selftest` is missing for the selected TPM version |
| `L-TPM-CONTROLLER-*` missing | TPM is configured as version `1`, `TPM{N}_MANUF1` is empty, or `tpm2_getcap` is missing |
| `L-TPM-CONTROLLER-*` fails | Expected vendor strings do not match `tpm2_getcap properties-fixed` output |
| `L-TPM-CAPABILITIES-*` fails | Capability name is not present in `tpm2_getcap -l`; check spelling and TPM support |
| `L-TPM-PCR-READABLE-F-*` fails | `tpm2_pcrread` ran but did not return PCR bank `0:` |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_TPM` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

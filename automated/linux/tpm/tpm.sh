#!/bin/bash
# shellcheck disable=SC2154
#
# tpm.sh
#
# Advantech BSP QA – TPM checks
# Ported from test_tpm() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${TPM_COUNT:=1}"

n=0
while [ "${n}" -lt "${TPM_COUNT}" ]; do
    eval "dev=\${TPM${n}_DEV}"
    eval "tpm_ver=\${TPM${n}_VERSION:-2}"
    eval "manuf1=\${TPM${n}_MANUF1}"
    eval "manuf2=\${TPM${n}_MANUF2}"
    eval "caps=\${TPM${n}_CAPS}"

    label="tpm${n}"
    req_dev="L-TPM-DEV-${label}"
    req_self="L-TPM-SELF-TEST-F-${label}"
    req_ctrl="L-TPM-CONTROLLER-${label}"
    req_cap="L-TPM-CAPABILITIES-${label}"
    req_pcr="L-TPM-PCR-READABLE-F-${label}"

    verbose_log "${req_dev}" "Checking TPM device node ${dev}"
    if chk_rw_cdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    if [ "${tpm_ver}" = "1" ]; then
        # TPM 1.x path
        export TPM_DEVICE="${dev}"
        unset TPM2TOOLS_TCTI
        if chk_cmd tpm_selftest; then
            verbose_log "${req_self}" "Running TPM 1.x self-test on ${dev}"
            if tpm_selftest -f >/dev/null 2>&1; then
                report_pass "${req_self}"
            else
                report_fail "${req_self}"
            fi
        else
            report_skip "${req_self}"
        fi
    else
        # TPM 2.0 path
        export TPM2TOOLS_TCTI="device:${dev}"
        unset TPM_DEVICE

        if chk_cmd tpm2_selftest; then
            verbose_log "${req_self}" "Running TPM 2.0 self-test on ${dev}"
            if tpm2_selftest -f >/dev/null 2>&1; then
                report_pass "${req_self}"
            else
                report_fail "${req_self}"
            fi
        else
            report_skip "${req_self}"
        fi

        # Manufacturer check
        if [ -n "${manuf1}" ] && chk_cmd tpm2_getcap; then
            verbose_log "${req_ctrl}" "Querying TPM vendor strings (expected: ${manuf1}${manuf2})"
            verbose_cmd "${req_ctrl}" tpm2_getcap properties-fixed
            m1=$(tpm2_getcap properties-fixed 2>/dev/null | xargs |
                 awk -F'TPM2_PT_VENDOR_STRING_1:' '{print $2}' |
                 awk -F'value:' '{print $2}' | awk '{print $1}')
            m2=$(tpm2_getcap properties-fixed 2>/dev/null | xargs |
                 awk -F'TPM2_PT_VENDOR_STRING_2:' '{print $2}' |
                 awk -F'value:' '{print $2}' | awk '{print $1}')
            verbose_log "${req_ctrl}" "TPM vendor: found='${m1}${m2}' expected='${manuf1}${manuf2}'"
            if [ "${m1}${m2}" = "${manuf1}${manuf2}" ]; then
                report_pass "${req_ctrl}"
            else
                report_fail "${req_ctrl}"
            fi
        fi

        # Capabilities
        for cap in ${caps}; do
            if chk_cmd tpm2_getcap; then
                verbose_log "${req_cap}" "Checking TPM capability '${cap}'"
                if tpm2_getcap -l 2>/dev/null | grep -q "${cap}"; then
                    report_pass "${req_cap}"
                else
                    report_fail "${req_cap}"
                fi
            else
                report_skip "${req_cap}"
            fi
        done

        # PCR readability
        if chk_cmd tpm2_pcrread; then
            verbose_log "${req_pcr}" "Reading TPM PCR bank 0"
            verbose_cmd "${req_pcr}" tpm2_pcrread
            if tpm2_pcrread 2>/dev/null | awk '{print $1$2$3}' | grep -q "^0:"; then
                report_pass "${req_pcr}"
            else
                report_fail "${req_pcr}"
            fi
        else
            report_skip "${req_pcr}"
        fi
    fi

    n=$((n + 1))
done

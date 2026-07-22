#!/bin/bash
# shellcheck disable=SC2154
#
# gpio.sh
#
# Advantech BSP QA – GPIO checks
# Ported from test_gpio() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${GPIO_COUNT:=1}"
: "${GPIO_PINS:=}"

# ─── Per-chip checks ──────────────────────────────────────────────────────────

n=0
while [ "${n}" -lt "${GPIO_COUNT}" ]; do
    eval "dev=\${GPIO${n}_DEV}"
    eval "chip=\${GPIO${n}_CHIP}"
    eval "controller=\${GPIO${n}_CONTROLLER}"
    eval "nlines=\${GPIO${n}_NLINES:-0}"

    label="gpio${n}"
    req_dev="L-GPIO-DEV-${label}"
    req_chip="L-GPIO-CHIP-${label}"
    req_ctrl="L-GPIO-CONTROLLER-${label}"
    req_lines="L-GPIO-LINES-${label}"

    verbose_log "${req_dev}" "Checking GPIO device node ${dev}"
    if chk_rw_cdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Chip sysfs entry
    if [ -n "${chip}" ]; then
        ce="/sys/class/gpio/${chip}"
        verbose_log "${req_chip}" "Checking sysfs entry ${ce}"
        if [ -e "${ce}" ]; then
            report_pass "${req_chip}"
        else
            report_fail "${req_chip}"
        fi

        # Controller label
        if [ -n "${controller}" ]; then
            tlabel=$(cat "${ce}/label" 2>/dev/null)
            verbose_log "${req_ctrl}" "GPIO chip label: found='${tlabel}' expected='${controller}'"
            if [ "${controller}" = "${tlabel}" ]; then
                report_pass "${req_ctrl}"
            else
                report_fail "${req_ctrl}"
            fi
        fi
    fi

    # Line count
    if [ "${nlines}" -gt 0 ] 2>/dev/null && chk_cmd gpioinfo; then
        iface=$(basename "${dev}")
        verbose_log "${req_lines}" "Querying GPIO line count for ${iface} (expected: ${nlines})"
        verbose_cmd "${req_lines}" gpioinfo
        nla=$(gpioinfo 2>/dev/null | grep "^${iface}" | awk '{print $3}')
        verbose_log "${req_lines}" "GPIO line count: found=${nla} expected=${nlines}"
        if echo "${nla}" | grep -qE '^[0-9]+$' && [ "${nlines}" -eq "${nla}" ] 2>/dev/null; then
            report_pass "${req_lines}"
        else
            report_fail "${req_lines}"
        fi
    fi

    n=$((n + 1))
done

# ─── Per-pin checks ───────────────────────────────────────────────────────────

sgpio="/sys/class/gpio"

for pin_spec in ${GPIO_PINS}; do
    # Format: <chip>:<pin>:<direction[.edge]>:<label>
    pin=$(echo "${pin_spec}"      | awk -F: '{print $2}')
    dir_edge=$(echo "${pin_spec}" | awk -F: '{print $3}')
    pin_label=$(echo "${pin_spec}"| awk -F: '{print $4}')

    direction=$(echo "${dir_edge}" | awk -F. '{print $1}')
    edge=$(echo "${dir_edge}"       | awk -F. '{print $2}')

    ppath="${sgpio}/gpio${pin}"
    dpath="${ppath}/direction"
    vpath="${ppath}/value"
    epath="${ppath}/edge"

    pre_exported=0
    [ -e "${dpath}" ] && pre_exported=1

    if [ "${pre_exported}" -eq 0 ]; then
        if ! echo "${pin}" > "${sgpio}/export" 2>/dev/null; then
            warn_msg "GPIO pin ${pin} (${pin_label}) not exportable"
            continue
        fi
    fi

    dfound=$(cat "${dpath}" 2>/dev/null)
    verbose_log "L-GPIO-INPUT" "Pin ${pin} (${pin_label}): direction found='${dfound}' expected='${direction}'"

    if [ "${direction}" = "out" ]; then
        req_dir="L-GPIO-OUTPUT"
    else
        req_dir="L-GPIO-INPUT"
    fi

    if [ "${dfound}" = "${direction}" ]; then
        report_pass "${req_dir}"
    else
        report_fail "${req_dir}"
    fi

    if [ "${dfound}" = "${direction}" ]; then
        case "${direction}" in
        in)
            val=$(cat "${vpath}" 2>/dev/null)
            verbose_log "L-GPIO-SENSED" "Pin ${pin} (${pin_label}): read value='${val}'"
            if [ -n "${val}" ]; then
                report_pass "L-GPIO-SENSED"
            else
                report_fail "L-GPIO-SENSED"
            fi
            ;;
        out)
            for v in 0 1; do
                verbose_log "L-GPIO-SET-HIGH-LOW" "Pin ${pin} (${pin_label}): writing value ${v}"
                if echo "${v}" > "${vpath}" 2>/dev/null; then
                    report_pass "L-GPIO-SET-HIGH-LOW"
                else
                    report_fail "L-GPIO-SET-HIGH-LOW"
                fi
            done
            ;;
        esac
    fi

    if [ -n "${edge}" ]; then
        verbose_log "L-GPIO-INT-SOURCE" "Pin ${pin} (${pin_label}): checking edge file ${epath}"
        if [ -e "${epath}" ]; then
            report_pass "L-GPIO-INT-SOURCE"
        else
            report_fail "L-GPIO-INT-SOURCE"
        fi
        efound=$(cat "${epath}" 2>/dev/null)
        verbose_log "L-GPIO-INTERRUPT" "Pin ${pin} (${pin_label}): edge found='${efound}' expected='${edge}'"
        if [ "${efound}" = "${edge}" ]; then
            report_pass "L-GPIO-INTERRUPT"
        else
            report_fail "L-GPIO-INTERRUPT"
        fi
    fi

    if [ "${pre_exported}" -eq 0 ]; then
        echo "${pin}" > "${sgpio}/unexport" 2>/dev/null || true
    fi
done

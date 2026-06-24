#!/bin/bash
#
# adv-test-lib.sh
#
# Advantech BSP QA – shared LAVA test helper library
#
# Source this file from every test-module script:
#   . ../lib/adv-test-lib.sh
#
# Derived from qa/test_board.sh
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

LANG=C
export LANG

# ─── Output / result-file defaults ──────────────────────────────────────────
#
# Each test script sets OUTPUT before sourcing this file, or accepts the
# default. RESULT_FILE is then set accordingly.

: "${OUTPUT:=$(pwd)/output}"
: "${RESULT_FILE:=${OUTPUT}/result.txt}"
export OUTPUT RESULT_FILE

create_out_dir() {
    local dir="${1:-${OUTPUT}}"
    mkdir -p "$dir"
}

# ─── LAVA test-case ID sanitisation ─────────────────────────────────────────
#
# Requirement IDs may contain:
#   ·  (U+00B7 MIDDLE DOT)  – instance separator, e.g. L-ETH-LINK·eth0
#   :  (colon)              – functional suffix, e.g. L-ETH-TX-THROUGHPUT:F
#
# Both characters are replaced with '-' to produce a valid LAVA test-case ID.

lava_id() {
    printf '%s' "$1" | sed 's/·/-/g; s/:/-/g'
}

# ─── Verbose per-test-case logging ──────────────────────────────────────────
#
# When ADV_VERBOSE is non-zero (the default), command output and context
# messages are captured into a per-test-case file ${OUTPUT}/<lava_id>.log.
# send-to-lava.sh emits the contents of that file between
# LAVA_SIGNAL_STARTTC/ENDTC, so the LAVA job log shows full diagnostics for
# every test case instead of a bare pass/fail line. Set ADV_VERBOSE=0 to keep
# the old quiet behaviour.

: "${ADV_VERBOSE:=1}"
export ADV_VERBOSE

# log_for <req_id> — echo the canonical per-test-case log path.
log_for() {
    printf '%s/%s.log' "${OUTPUT}" "$(lava_id "$1")"
}

# log_msg <req_id> <message…> — append a context line to the id's log
# (e.g. expected vs actual values, device paths, parameters).
log_msg() {
    [ "${ADV_VERBOSE}" -ne 0 ] 2>/dev/null || return 0
    local id logf
    id="$1"; shift
    logf=$(log_for "${id}")
    mkdir -p "$(dirname "${logf}")"
    printf '%s\n' "$*" >> "${logf}"
}

# _log_result <req_id> <result> [extra…] — append the final outcome line.
_log_result() {
    [ "${ADV_VERBOSE}" -ne 0 ] 2>/dev/null || return 0
    local id="$1" result="$2"
    shift 2
    local logf
    logf=$(log_for "${id}")
    mkdir -p "$(dirname "${logf}")"
    printf 'RESULT: %s %s %s\n' "$(lava_id "${id}")" "${result}" "$*" >> "${logf}"
}

# ─── Result reporters ────────────────────────────────────────────────────────

report_pass() {
    local id
    id=$(lava_id "$1")
    echo "${id} pass" | tee -a "${RESULT_FILE}"
    _log_result "$1" pass
}

report_fail() {
    local id
    id=$(lava_id "$1")
    echo "${id} fail" | tee -a "${RESULT_FILE}"
    _log_result "$1" fail
}

report_skip() {
    local id
    id=$(lava_id "$1")
    echo "${id} skip" | tee -a "${RESULT_FILE}"
    _log_result "$1" skip
}

report_unknown() {
    local id
    id=$(lava_id "$1")
    echo "${id} unknown" | tee -a "${RESULT_FILE}"
    _log_result "$1" unknown
}

# report_metric <req_id> <pass|fail|skip> <measurement> [units]
# Emits the extended LAVA result line that send-to-lava.sh parses for
# measurement/units fields.
report_metric() {
    local id result measurement units
    id=$(lava_id "$1")
    result="$2"
    measurement="$3"
    units="${4:-}"
    if [ -n "$units" ]; then
        echo "${id} ${result} ${measurement} ${units}" | tee -a "${RESULT_FILE}"
    else
        echo "${id} ${result} ${measurement}" | tee -a "${RESULT_FILE}"
    fi
    _log_result "$1" "${result}" "measurement=${measurement} ${units}"
}

# run_adv_test <req_id> <shell-command…>
# Evaluates the command; reports pass if exit-0, fail otherwise.
run_adv_test() {
    local id="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        report_pass "$id"
        return 0
    else
        report_fail "$id"
        return 1
    fi
}

# run_logged <req_id> <command…>
# Like run_adv_test, but captures the command's stdout+stderr into the test
# case's log (${OUTPUT}/<lava_id>.log) instead of discarding it, so the output
# is surfaced in the LAVA job log. Reports pass on exit 0, fail otherwise.
run_logged() {
    local id="$1"
    shift
    local rc logf
    if [ "${ADV_VERBOSE}" -ne 0 ] 2>/dev/null; then
        logf=$(log_for "${id}")
        mkdir -p "$(dirname "${logf}")"
        { printf '+ %s\n' "$*"; "$@" 2>&1; } >> "${logf}"
        rc=$?
    else
        "$@" >/dev/null 2>&1
        rc=$?
    fi
    if [ "${rc}" -eq 0 ]; then
        report_pass "${id}"
    else
        report_fail "${id}"
    fi
    return "${rc}"
}

# ─── Root / privilege check ──────────────────────────────────────────────────

check_root() {
    [ "$(id -ru)" -eq 0 ]
}

# ─── Command-existence helper ────────────────────────────────────────────────

chk_cmd() {
    type "$1" >/dev/null 2>&1
}

# ─── Device-file permission checks ──────────────────────────────────────────

# chk_rw_tdev <path> <type-char>
# Verifies that the file exists, has the expected type, and is readable+writable.
chk_rw_tdev() {
    local dev="$1" type_flag="$2" err=0
    [ -e "$dev" ]   || err=$((err + 1))
    case "${type_flag}" in
        c) [ -c "$dev" ] 2>/dev/null || err=$((err + 1)) ;;
        b) [ -b "$dev" ] 2>/dev/null || err=$((err + 1)) ;;
        *) err=$((err + 1)) ;;
    esac
    [ -r "$dev" ]   || err=$((err + 1))
    [ -w "$dev" ]   || err=$((err + 1))
    [ "$err" -eq 0 ]
}

chk_rw_cdev() { chk_rw_tdev "$1" c; }
chk_rw_bdev() { chk_rw_tdev "$1" b; }

# ─── Bus controller check ────────────────────────────────────────────────────
#
# chk_bus_pci <bus_id> <req_id>
# chk_bus_soc <bus_id> <dev_type> <dev_sf> <dname> <req_id>

chk_bus_pci() {
    local bus_id="$1" req_id="$2"
    if lspci | grep -qi "$bus_id"; then
        report_pass "$req_id"
    else
        report_fail "$req_id"
    fi
}

chk_bus_soc() {
    local bus_id="$1" dev_type="$2" dev_sf="$3" dname="$4" req_id="$5"
    dname=$(basename "$dname")
    local found=0 dt p pf
    for dt in $dev_type pwm tpm; do
        p=$(find /sys/devices/platform/ -name "${bus_id}.${dt}" -type d 2>/dev/null | head -1)
        [ -z "$p" ] && continue
        pf=$(find "$p" -name "$dname" 2>/dev/null | grep ".*${dev_sf}\.${dname}$" | head -1)
        if [ -n "$pf" ]; then found=1; break; fi
        if [ "$dt" = "power-domain" ] || [ "$dt" = "clock-controller" ]; then
            [ -e "$p/$dev_sf" ] && found=1 && break
        fi
    done
    if [ "$found" -eq 1 ]; then
        report_pass "$req_id"
    else
        report_fail "$req_id"
    fi
}

# chk_bus <bus> <bus_id> <dev_type> <dev_sf> <dname> <req_id>
chk_bus() {
    local bus="$1" bus_id="$2" dev_type="$3" dev_sf="$4" dname="$5" req_id="$6"
    case "${bus,,}" in
    pci) chk_bus_pci  "$bus_id" "$req_id" ;;
    soc) chk_bus_soc  "$bus_id" "$dev_type" "$dev_sf" "$dname" "$req_id" ;;
    *)   report_fail "$req_id" ;;
    esac
}

# ─── Networking helpers ──────────────────────────────────────────────────────

# get_ip <iface> [4|6]   – echoes address/prefix, e.g. 192.168.1.10/24
get_ip() {
    local iface="$1" proto="${2:-4}"
    if [ "$proto" = "6" ]; then
        ip a show dev "$iface" 2>/dev/null |
            grep '[[:space:]]*inet6 ' | grep -v '/128' | head -1 | awk '{print $2}'
    else
        ip a show dev "$iface" 2>/dev/null |
            grep '[[:space:]]*inet ' | head -1 | awk '{print $2}'
    fi
}

# ─── Disk helpers ────────────────────────────────────────────────────────────

disk_type() {
    local dev="$1" dn dt
    dn=$(basename "$dev")
    dt=$(cat "/sys/block/${dn}/device/type" 2>/dev/null)
    case "$dt" in
    SD|MMC) ;;
    *) dt=$(lsblk -o TRAN "$dev" 2>/dev/null | tail -1 | xargs) ;;
    esac
    [ -n "$dt" ] || dt=unknown
    echo "${dt^^}"
}

disk_exists() {
    [ -e "$1" ] && [ -b "$1" ] && fdisk -l "$1" >/dev/null 2>&1
}

drop_caches() {
    sync
    echo 3 > /proc/sys/vm/drop_caches
}

# ─── RAM helpers ─────────────────────────────────────────────────────────────

physical_ram_mmap_MB() {
    local lo hi
    lo=$(grep '^[^ ]' /proc/iomem 2>/dev/null | grep -v dma |
         grep 'System RAM' | head -1 | awk -F- '{print $1}' | xargs)
    hi=$(grep '^[^ ]' /proc/iomem 2>/dev/null | grep -v dma |
         grep 'System RAM' | tail -1 | awk -F- '{print $2}' | awk '{print $1}')
    if [ -n "$lo" ] && [ -n "$hi" ]; then
        printf '%d\n' $(( (0x$hi - 0x$lo + 1) / (1024 * 1024) ))
    else
        echo 0
    fi
}

physical_ram_dmidecode_MB() {
    chk_cmd dmidecode || { echo 0; return 1; }
    local mb=0 val unit
    while IFS= read -r line; do
        val=$(awk '{print $1}' <<<"$line")
        unit=$(awk '{print $2}' <<<"$line")
        echo "$unit" | grep -qi 'MB' && mb=$((mb + val))
        echo "$unit" | grep -qi 'GB' && mb=$((mb + val * 1024))
    done < <(dmidecode | grep 'Volatile Size' | grep -v 'Non-Volatile' | awk -F: '{print $2}')
    echo "$mb"
}

physical_ram_MB() {
    local m
    for m in "$(physical_ram_dmidecode_MB)" "$(physical_ram_mmap_MB)"; do
        [ "$((m + 0))" -gt 0 ] && echo "$m" && return
    done
    echo 0
}

physical_ram_MT() {
    chk_cmd dmidecode || { echo 0; return 1; }
    dmidecode -t memory |
        grep 'Configured' | grep 'Speed' | grep 'MT' |
        awk -F'MT' '{print $1}' | awk '{print $NF}' | head -1
}

# ─── OS / distro helpers ─────────────────────────────────────────────────────

get_distro_id() {
    local d c
    # shellcheck disable=SC1091
    d=$(. /etc/os-release 2>/dev/null; echo "${ID:-}")
    c=$(. /etc/os-release 2>/dev/null; echo "${CPE_NAME:-}")
    if echo "$d" | grep -q '^fsl-imx' ||
       echo "$c" | grep -q openembedded ||
       echo "$d" | grep -qi poky; then
        echo yocto
    else
        echo "$d"
    fi
}

get_distro_ver() {
    # shellcheck disable=SC1091
    . /etc/os-release 2>/dev/null
    echo "${VERSION_ID:-}"
}

is_yocto() { [ "$(get_distro_id)" = yocto ]; }

# ─── Misc ────────────────────────────────────────────────────────────────────

ts_ms()    { date +%s%3N; }
info_msg() { printf 'INFO: %s\n' "$*" >&2; }
warn_msg() { printf 'WARNING: %s\n' "$*" >&2; }
error_msg(){ printf 'ERROR: %s\n' "$*" >&2; }

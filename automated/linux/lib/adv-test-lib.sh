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

# ─── Verbose-logging toggle ──────────────────────────────────────────────────
#
# Set VERBOSE=1 (or pass it via the YAML params block) to enable per-test-case
# diagnostic log files and real-time progress banners.  When VERBOSE=0 (the
# default) all output from diagnostic commands is suppressed, matching the
# previous behaviour exactly.

: "${VERBOSE:=0}"
export VERBOSE

create_out_dir() {
    local dir="${1:-${OUTPUT}}"
    mkdir -p "$dir"
}

# ─── Verbose helpers ─────────────────────────────────────────────────────────
#
# verbose_log <id> <message>
#   When VERBOSE=1: appends an INFO line to the per-test log file
#   (OUTPUT/<lava_id>.log) and echoes it to stderr.  No-op otherwise.
#
# verbose_cmd <id> <cmd…>
#   When VERBOSE=1: runs the command, tees combined stdout+stderr to the
#   per-test log file and to stderr, then returns the command's exit code.
#   No-op (returns 0) when VERBOSE=0.

verbose_log() {
    [ "${VERBOSE}" = "1" ] || return 0
    local id logf
    id=$(lava_id "$1")
    logf="${OUTPUT}/${id}.log"
    shift
    printf 'INFO: %s\n' "$*" | tee -a "${logf}" >&2
}

verbose_cmd() {
    [ "${VERBOSE}" = "1" ] || return 0
    local id logf rc
    id=$(lava_id "$1")
    logf="${OUTPUT}/${id}.log"
    shift
    "$@" 2>&1 | tee -a "${logf}" >&2
    rc=${PIPESTATUS[0]}
    return "${rc}"
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

# ─── Result reporters ────────────────────────────────────────────────────────

report_pass() {
    local id
    id=$(lava_id "$1")
    echo "${id} pass" | tee -a "${RESULT_FILE}"
    if [ "${VERBOSE}" = "1" ]; then
        printf 'RESULT: pass\n' | tee -a "${OUTPUT}/${id}.log" >&2
    fi
}

report_fail() {
    local id
    id=$(lava_id "$1")
    echo "${id} fail" | tee -a "${RESULT_FILE}"
    if [ "${VERBOSE}" = "1" ]; then
        printf 'RESULT: fail\n' | tee -a "${OUTPUT}/${id}.log" >&2
    fi
}

report_skip() {
    local id
    id=$(lava_id "$1")
    echo "${id} skip" | tee -a "${RESULT_FILE}"
    if [ "${VERBOSE}" = "1" ]; then
        printf 'RESULT: skip\n' | tee -a "${OUTPUT}/${id}.log" >&2
    fi
}

report_unknown() {
    local id
    id=$(lava_id "$1")
    echo "${id} unknown" | tee -a "${RESULT_FILE}"
    if [ "${VERBOSE}" = "1" ]; then
        printf 'RESULT: unknown\n' | tee -a "${OUTPUT}/${id}.log" >&2
    fi
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
    if [ "${VERBOSE}" = "1" ]; then
        if [ -n "$units" ]; then
            printf 'RESULT: %s  measurement=%s %s\n' \
                "${result}" "${measurement}" "${units}" | tee -a "${OUTPUT}/${id}.log" >&2
        else
            printf 'RESULT: %s  measurement=%s\n' \
                "${result}" "${measurement}" | tee -a "${OUTPUT}/${id}.log" >&2
        fi
    fi
}

# run_adv_test <req_id> <shell-command…>
# Evaluates the command; reports pass if exit-0, fail otherwise.
# When VERBOSE=1 the command's output is captured to the per-test log file.
run_adv_test() {
    local id="$1"
    shift
    if [ "${VERBOSE}" = "1" ]; then
        if verbose_cmd "${id}" "$@"; then
            report_pass "$id"
            return 0
        else
            report_fail "$id"
            return 1
        fi
    else
        if "$@" >/dev/null 2>&1; then
            report_pass "$id"
            return 0
        else
            report_fail "$id"
            return 1
        fi
    fi
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

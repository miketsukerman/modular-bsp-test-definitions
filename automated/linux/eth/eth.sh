#!/bin/bash
# shellcheck disable=SC2154
#
# eth.sh
#
# Advantech BSP QA – Ethernet checks
# Ported from test_eth() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${ETH_COUNT:=1}"
: "${IPERF3_SERVER_IP:=}"
: "${IPERF3_DURATION:=5}"
: "${DNS_CHECK_HOSTS:=advantech.com google.com}"

if [ -z "${PING_IPV4_HOSTS+x}" ]; then
    if [ -n "${PING_CHECK_HOSTS+x}" ]; then
        PING_IPV4_HOSTS="${PING_CHECK_HOSTS}"
    else
        PING_IPV4_HOSTS="advantech.com google.com"
    fi
fi

if [ -z "${PING_IPV6_HOSTS+x}" ]; then
    PING_IPV6_HOSTS=""
fi

# Determine whether default routes exist before external ping checks.
has_default_v4=0
has_default_v6=0
ip -4 route show default >/dev/null 2>&1 && has_default_v4=1
ip -6 route show default >/dev/null 2>&1 && has_default_v6=1

# ─── Per-interface checks ─────────────────────────────────────────────────────

n=0
while [ "${n}" -lt "${ETH_COUNT}" ]; do
    eval "iface=\${ETH${n}_DEV}"
    eval "bus=\${ETH${n}_BUS}"
    eval "bus_id=\${ETH${n}_BUS_ID}"
    eval "link=\${ETH${n}_LINK}"
    eval "wol_feat=\${ETH${n}_WOL_FEATURED}"
    eval "wol_wakeup=\${ETH${n}_WOL_WAKEUP}"
    eval "min_tx=\${ETH${n}_MIN_TX_SPEED:-0}"
    eval "min_rx=\${ETH${n}_MIN_RX_SPEED:-0}"

    label="eth${n}"
    req_dev="L-ETH-DEV-${label}"
    req_ctrl="L-ETH-CONTROLLER-${label}"
    req_link="L-ETH-LINK-${label}"
    req_cfg="L-ETH-CONFIGURED-${label}"
    req_ip4="L-ETH-IPV4-ADDRESS-${label}"
    req_ip6="L-ETH-IPV6-ADDRESS-${label}"
    req_wol_feat="L-ETH-WAKEUP-FEATURED-${label}"
    req_wol_en="L-ETH-WAKEUP-ENABLED-${label}"
    req_tx="L-ETH-TX-THROUGHPUT-F-${label}"
    req_rx="L-ETH-RX-THROUGHPUT-F-${label}"

    # Device existence
    verbose_log "${req_dev}" "Checking interface ${iface}"
    verbose_cmd "${req_dev}" ip addr show "${iface}"
    if ip addr show "${iface}" >/dev/null 2>&1; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Bus controller
    if [ -n "${bus}" ] && [ -n "${bus_id}" ]; then
        chk_bus "${bus}" "${bus_id}" ethernet net "${iface}" "${req_ctrl}"
    fi

    # Link speed
    if [ -n "${link}" ] && chk_cmd ethtool; then
        verbose_log "${req_link}" "Querying link speed for ${iface} (expected: ${link} Mbps)"
        verbose_cmd "${req_link}" ethtool "${iface}"
        la=$(ethtool "${iface}" 2>/dev/null | grep Speed: | awk '{print $2}' | awk -F'M' '{print $1}')
        verbose_log "${req_link}" "Detected link speed: ${la} Mbps"
        if [ "${la}" = "${link}" ]; then
            report_pass "${req_link}"
        else
            report_fail "${req_link}"
        fi
    fi

    # Interface UP
    flags=$(ip addr show "${iface}" 2>/dev/null | awk -F'<' '{print $2}' | awk -F'>' '{print $1}' | tr ',' ' ')
    verbose_log "${req_cfg}" "Interface flags for ${iface}: ${flags}"
    if echo "${flags}" | grep -qw "UP"; then
        report_pass "${req_cfg}"
    else
        report_fail "${req_cfg}"
        n=$((n + 1))
        continue
    fi

    # IPv4 address
    ip4=$(get_ip "${iface}" 4)
    ip4_plain=$(echo "${ip4}" | awk -F/ '{print $1}')
    verbose_log "${req_ip4}" "IPv4 address for ${iface}: ${ip4:-<none>}"
    if [ -n "${ip4}" ]; then
        report_pass "${req_ip4}"
    else
        report_fail "${req_ip4}"
    fi

    # IPv6 address
    ip6=$(get_ip "${iface}" 6)
    verbose_log "${req_ip6}" "IPv6 address for ${iface}: ${ip6:-<none>}"
    if [ -n "${ip6}" ]; then
        report_pass "${req_ip6}"
    else
        report_fail "${req_ip6}"
    fi

    # Wake-on-LAN
    if [ -n "${wol_feat}" ] && chk_cmd ethtool; then
        caps=$(ethtool "${iface}" 2>/dev/null | grep "Supports Wake-on:" | awk '{print $NF}')
        verbose_log "${req_wol_feat}" "WoL capabilities for ${iface}: ${caps:-<none>} (expected: ${wol_feat})"
        wol_feat_lc=$(echo "${wol_feat}" | tr '[:upper:]' '[:lower:]')
        case "${wol_feat_lc}" in
        y|yes|true|1)
            # Legacy boolean expectation: pass when at least one WoL mode is supported.
            if [ -n "${caps}" ] && [ "${caps}" != "d" ]; then
                report_pass "${req_wol_feat}"
            else
                report_fail "${req_wol_feat}"
            fi
            ;;
        n|no|false|0)
            # Legacy boolean expectation: pass when no WoL mode is supported.
            if [ -z "${caps}" ] || [ "${caps}" = "d" ]; then
                report_pass "${req_wol_feat}"
            else
                report_fail "${req_wol_feat}"
            fi
            ;;
        *)
            if echo "${caps}" | grep -q "${wol_feat}"; then
                report_pass "${req_wol_feat}"
            else
                report_fail "${req_wol_feat}"
            fi
            ;;
        esac

        if [ -n "${wol_wakeup}" ]; then
            we=$(cat "/sys/class/net/${iface}/device/power/wakeup" 2>/dev/null)
            exp_wakeup_lc=$(echo "${wol_wakeup}" | tr '[:upper:]' '[:lower:]')
            case "${exp_wakeup_lc}" in
            y|yes|true|1) exp_wakeup="enabled" ;;
            n|no|false|0) exp_wakeup="disabled" ;;
            *) exp_wakeup="${wol_wakeup}" ;;
            esac
            verbose_log "${req_wol_en}" "WoL wakeup for ${iface}: found='${we:-<unavailable>}' expected='${exp_wakeup}'"
            if [ "${we}" = "${exp_wakeup}" ]; then
                report_pass "${req_wol_en}"
            elif [ -z "${we}" ] && [ "${exp_wakeup}" = "disabled" ]; then
                # Some drivers expose no wakeup node; treat that as not wake-capable.
                report_pass "${req_wol_en}"
            else
                report_fail "${req_wol_en}"
            fi
        fi
    fi

    # iperf3 throughput (functional – skip when no server IP)
    # Verbose mode logs only the summary line to keep log sizes small.
    if [ -z "${IPERF3_SERVER_IP}" ] || [ -z "${ip4_plain}" ]; then
        report_skip "${req_tx}"
        report_skip "${req_rx}"
    else
        if chk_cmd iperf3; then
            # TX
            if [ "${min_tx}" -gt 0 ] 2>/dev/null; then
                verbose_log "${req_tx}" "Running iperf3 TX test to ${IPERF3_SERVER_IP} for ${IPERF3_DURATION}s"
                tx_raw=$(iperf3 -c "${IPERF3_SERVER_IP}" -B "${ip4_plain}" \
                         -t "${IPERF3_DURATION}" -4 2>/dev/null |
                         grep -i receiver | awk '{print $7}')
                tx_mbps=$(echo "${tx_raw}" | awk '{printf "%d", $1}')
                verbose_log "${req_tx}" "TX result: ${tx_mbps} Mbps (min: ${min_tx} Mbps)"
                if [ "${tx_mbps}" -ge "${min_tx}" ] 2>/dev/null; then
                    report_metric "${req_tx}" "pass" "${tx_mbps}" "Mbps"
                else
                    report_metric "${req_tx}" "fail" "${tx_mbps}" "Mbps"
                fi
            else
                report_skip "${req_tx}"
            fi
            # RX
            if [ "${min_rx}" -gt 0 ] 2>/dev/null; then
                verbose_log "${req_rx}" "Running iperf3 RX test to ${IPERF3_SERVER_IP} for ${IPERF3_DURATION}s"
                rx_raw=$(iperf3 -c "${IPERF3_SERVER_IP}" -B "${ip4_plain}" \
                         -t "${IPERF3_DURATION}" -4 -R 2>/dev/null |
                         grep -i receiver | awk '{print $7}')
                rx_mbps=$(echo "${rx_raw}" | awk '{printf "%d", $1}')
                verbose_log "${req_rx}" "RX result: ${rx_mbps} Mbps (min: ${min_rx} Mbps)"
                if [ "${rx_mbps}" -ge "${min_rx}" ] 2>/dev/null; then
                    report_metric "${req_rx}" "pass" "${rx_mbps}" "Mbps"
                else
                    report_metric "${req_rx}" "fail" "${rx_mbps}" "Mbps"
                fi
            else
                report_skip "${req_rx}"
            fi
        else
            report_skip "${req_tx}"
            report_skip "${req_rx}"
        fi
    fi

    n=$((n + 1))
done

# ─── DNS and ping checks ──────────────────────────────────────────────────────

for host in ${DNS_CHECK_HOSTS}; do
    for proto in 4 6; do
        case "${proto}" in
        4) rec=A ;;
        6) rec=AAAA ;;
        esac
        resolved=""
        if chk_cmd host; then
            resolved=$(host -t "${rec}" "${host}" 2>/dev/null | head -1 | awk '{print $NF}')
        else
            resolved=$(ping -c 1 "-${proto}" "${host}" 2>/dev/null | head -1 |
                       awk -F'(' '{print $2}' | awk -F')' '{print $1}')
        fi
        verbose_log "L-DNS-IPV${proto}" "DNS lookup ${rec} ${host}: ${resolved:-<not resolved>}"
        if [ -n "${resolved}" ]; then
            report_pass "L-DNS-IPV${proto}"
        else
            report_fail "L-DNS-IPV${proto}"
        fi
    done
done

for host in ${PING_IPV4_HOSTS}; do
    if [ "${has_default_v4}" -ne 1 ]; then
        verbose_log "L-ETH-IPV4-PING" "Skipping IPv4 ping to ${host}: no default IPv4 route"
        report_skip "L-ETH-IPV4-PING"
        continue
    fi
    verbose_log "L-ETH-IPV4-PING" "Pinging ${host} over IPv4"
    if ping -4 -c 1 "${host}" >/dev/null 2>&1; then
        report_pass "L-ETH-IPV4-PING"
    else
        report_fail "L-ETH-IPV4-PING"
    fi
done

for host in ${PING_IPV6_HOSTS}; do
    if [ "${has_default_v6}" -ne 1 ]; then
        verbose_log "L-ETH-IPV6-PING" "Skipping IPv6 ping to ${host}: no default IPv6 route"
        report_skip "L-ETH-IPV6-PING"
        continue
    fi
    verbose_log "L-ETH-IPV6-PING" "Pinging ${host} over IPv6"
    if ping -6 -c 1 "${host}" >/dev/null 2>&1; then
        report_pass "L-ETH-IPV6-PING"
    else
        report_fail "L-ETH-IPV6-PING"
    fi
done

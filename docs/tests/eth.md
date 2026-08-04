# eth (`adv-eth`)

Ethernet checks: interface presence, optional bus controller, link speed, UP
state, IPv4/IPv6 addressing, Wake-on-LAN, optional `iperf3` TX/RX throughput,
DNS resolution, and ping connectivity.

* **Definition:** [`automated/linux/eth/eth.yaml`](../../automated/linux/eth/eth.yaml)
* **Script:** [`automated/linux/eth/eth.sh`](../../automated/linux/eth/eth.sh)

## Scope

**Covered**

* Each configured network interface exists and is administratively UP.
* Optional SoC/PCI controller lookup and link-speed check.
* IPv4 and IPv6 address presence on each configured interface.
* Optional Wake-on-LAN capability and sysfs wakeup state.
* Optional TX/RX throughput to an `iperf3` server, reported in `Mbps`.
* DNS A/AAAA lookups and IPv4/IPv6 ping checks for configured hosts.

**Not covered**

* Packet loss, latency, jumbo-frame, VLAN, bonding or failover validation.
* Cable diagnostics and PHY electrical tests.
* Starting or managing the host-side `iperf3` server.

## Prerequisites

* **Hardware:** configured Ethernet ports must be connected. Throughput checks
  require a reachable host running `iperf3 -s` at `IPERF3_SERVER_IP`.
* **Target tools:** `ip`, `ping`, `awk`; `ethtool` is needed for link speed and
  Wake-on-LAN checks, `iperf3` for throughput, `host` for DNS lookups when
  present, and `lspci` for PCI controller checks.
* **Root:** not required for the script itself, although target network setup
  may require privileged configuration before running it.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ETH_COUNT` | `"1"` | Number of Ethernet interfaces to iterate over (`eth0` … `eth<COUNT-1>`) |
| `ETH{N}_DEV` | `eth0` | Network interface name for interface `N` |
| `ETH{N}_BUS` | `"soc"` | Controller bus type (`soc` or `pci`); empty = controller check not emitted |
| `ETH{N}_BUS_ID` | `"29950000"` | Bus identifier used by the controller check; empty = controller check not emitted |
| `ETH{N}_LINK` | `"100"` | Expected link speed in `Mbps`; empty or missing `ethtool` = check not emitted |
| `ETH{N}_WOL_FEATURED` | `""` | Required Wake-on-LAN capability character, such as `g`; empty = WoL checks not emitted |
| `ETH{N}_WOL_WAKEUP` | `""` | Expected `/sys/class/net/<iface>/device/power/wakeup` value; empty = wakeup-state check not emitted |
| `ETH{N}_MIN_TX_SPEED` | `"90"` | Minimum TX throughput in `Mbps`; `0` = TX result is skipped |
| `ETH{N}_MIN_RX_SPEED` | `"90"` | Minimum RX throughput in `Mbps`; `0` = RX result is skipped |
| `IPERF3_SERVER_IP` | `""` | Host-side `iperf3` server IP; empty = throughput results are skipped |
| `IPERF3_DURATION` | `"5"` | `iperf3` duration in seconds |
| `DNS_CHECK_HOSTS` | `"advantech.com google.com"` | Space-separated hostnames for A and AAAA lookup checks |
| `PING_CHECK_HOSTS` | `"advantech.com google.com"` | Space-separated hostnames for IPv4 and IPv6 ping checks |
| `VERBOSE` | `"0"` | `"1"` enables per-test-case diagnostic logs |

Only `ETH{N}_DEV` is mandatory per interface; optional empty values remove or
skip the matching checks as described above.

## Test cases

IDs are shown in sanitised (LAVA) form. `${label}` is `eth<N>` for interface
`N`.

| Test case ID | Functional | Pass | Fail | Skip / not emitted |
|--------------|:----------:|------|------|--------------------|
| `L-ETH-DEV-${label}` | | `ip addr show <iface>` succeeds | Interface is missing (remaining checks for this interface are abandoned) | — |
| `L-ETH-CONTROLLER-${label}` | | Shared bus helper finds the configured SoC/PCI controller | Controller is not found or bus type is unsupported | Not emitted when `ETH{N}_BUS` or `ETH{N}_BUS_ID` is empty |
| `L-ETH-LINK-${label}` | | `ethtool` speed equals `ETH{N}_LINK` | Speed differs or cannot be parsed | Not emitted when `ETH{N}_LINK` is empty or `ethtool` is missing |
| `L-ETH-CONFIGURED-${label}` | | Interface flags include `UP` | Interface is not UP (remaining checks for this interface are abandoned) | — |
| `L-ETH-IPV4-ADDRESS-${label}` | | Interface has a non-`/128` IPv4 address | No IPv4 address found | Only after `L-ETH-CONFIGURED-${label}` passes |
| `L-ETH-IPV6-ADDRESS-${label}` | | Interface has a non-`/128` IPv6 address | No IPv6 address found | Only after `L-ETH-CONFIGURED-${label}` passes |
| `L-ETH-WAKEUP-FEATURED-${label}` | | `ethtool` Wake-on-LAN capabilities contain `ETH{N}_WOL_FEATURED` | Capability is absent | Not emitted when `ETH{N}_WOL_FEATURED` is empty or `ethtool` is missing |
| `L-ETH-WAKEUP-ENABLED-${label}` | | sysfs wakeup value equals `ETH{N}_WOL_WAKEUP` | Wakeup value differs or is unreadable | Not emitted when `ETH{N}_WOL_WAKEUP` is empty, or the WoL capability check is not emitted |
| `L-ETH-TX-THROUGHPUT-F-${label}` | ✓ | `iperf3` TX throughput is at least `ETH{N}_MIN_TX_SPEED`; reports metric in `Mbps` | Measured TX throughput is below the threshold or unparsable; reports metric in `Mbps` | Skip when `IPERF3_SERVER_IP` is empty, no IPv4 address exists, `iperf3` is missing, or min speed is `0` |
| `L-ETH-RX-THROUGHPUT-F-${label}` | ✓ | `iperf3 -R` RX throughput is at least `ETH{N}_MIN_RX_SPEED`; reports metric in `Mbps` | Measured RX throughput is below the threshold or unparsable; reports metric in `Mbps` | Skip when `IPERF3_SERVER_IP` is empty, no IPv4 address exists, `iperf3` is missing, or min speed is `0` |
| `L-DNS-IPV4` | | A record lookup returns a value (emitted once per `DNS_CHECK_HOSTS` entry) | Lookup returns no value | Not emitted when `DNS_CHECK_HOSTS` is empty |
| `L-DNS-IPV6` | | AAAA record lookup returns a value (emitted once per `DNS_CHECK_HOSTS` entry) | Lookup returns no value | Not emitted when `DNS_CHECK_HOSTS` is empty |
| `L-ETH-IPV4-PING` | | `ping -4 -c 1` succeeds (emitted once per `PING_CHECK_HOSTS` entry) | Ping fails | Not emitted when `PING_CHECK_HOSTS` is empty |
| `L-ETH-IPV6-PING` | | `ping -6 -c 1` succeeds (emitted once per `PING_CHECK_HOSTS` entry) | Ping fails | Not emitted when `PING_CHECK_HOSTS` is empty |

The throughput checks use `report_metric`, so LAVA receives the integer
measurement and `Mbps` units alongside the pass/fail result.

## Running locally

```sh
cd automated/linux/eth
ETH_COUNT=1 \
ETH0_DEV=eth0 \
ETH0_BUS=soc \
ETH0_BUS_ID=29950000 \
ETH0_LINK=100 \
ETH0_MIN_TX_SPEED=90 \
ETH0_MIN_RX_SPEED=90 \
IPERF3_SERVER_IP=192.0.2.10 \
IPERF3_DURATION=5 \
bash eth.sh
cat output/result.txt
```

## Verbose logging

With `VERBOSE=1` the script writes `output/<test-case-id>.log` for interface,
link, UP-state, IP address, Wake-on-LAN, throughput, DNS and ping checks. The
throughput logs contain the parsed summary value and each log ends in a
`RESULT:` line. LAVA surfaces these logs alongside the test result.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| `L-ETH-DEV-*` fails | Wrong interface name, missing driver, or interface not created by the kernel |
| `L-ETH-LINK-*` missing | `ethtool` is not installed, or `ETH{N}_LINK` is empty |
| `L-ETH-CONFIGURED-*` fails | Interface is down; bring it up and configure addressing before running the test |
| `L-ETH-TX-THROUGHPUT-F-*` or `L-ETH-RX-THROUGHPUT-F-*` skips | `IPERF3_SERVER_IP` is empty, target has no IPv4 address, `iperf3` is missing, or min speed is `0` |
| `L-DNS-IPV6` or `L-ETH-IPV6-PING` fails | Network path or DNS does not support IPv6 |

## Board parameters

Generated by [`conf_to_yaml.py`](../../automated/linux/tools/conf_to_yaml.py)
from the `CFGA_ETH` array of a board `.conf`.

---

[Suite index](README.md) · [LAVA usage](../lava-usage.md) ·
[Extending tests](../extending-tests.md)

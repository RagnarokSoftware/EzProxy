# Configuring a Secondary VNIC on Oracle Cloud (Ubuntu)

## Problem

After adding a secondary VNIC to an Oracle Cloud instance, the network interface appears in the OS but has no IP address and is not functional.

## Root Cause

Oracle Cloud's DHCP works via the instance metadata service (`169.254.169.254`) for the **primary VNIC only**. Secondary VNICs must be configured manually with:

1. A static IP address (assigned in Oracle Cloud Console)
2. Policy-based routing (to prevent asymmetric routing)

## Prerequisites

From Oracle Cloud Console, note down:
- **Private IP**: The IP assigned to the secondary VNIC (e.g., `10.0.0.94`)
- **Subnet CIDR**: The subnet mask (e.g., `/24`)
- **MAC Address**: Found via `ip link show` on the instance
- **Gateway**: Usually the first IP in the subnet (e.g., `10.0.0.1`)

## Solution

### Step 1: Identify the Secondary Interface

```bash
ip addr show
```

The secondary NIC will show as `DOWN` with no IPv4 address:

```
3: enp1s0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN
    link/ether 02:00:17:04:f6:a7 brd ff:ff:ff:ff:ff:ff
```

### Step 2: Create Netplan Configuration

Create `/etc/netplan/51-secondary-nic.yaml`:

```yaml
network:
  version: 2
  ethernets:
    enp1s0:
      match:
        macaddress: "02:00:17:04:f6:a7"
      addresses:
        - 10.0.0.94/24
      set-name: "enp1s0"
      routing-policy:
        - from: 10.0.0.94
          table: 100
      routes:
        - to: default
          via: 10.0.0.1
          table: 100
```

**Key configuration elements:**

| Field | Purpose |
|-------|---------|
| `match.macaddress` | Ensures config applies to correct interface |
| `addresses` | Static IP from Oracle Cloud Console |
| `routing-policy` | Routes traffic FROM this IP to a separate routing table |
| `routes` | Default gateway in the separate table |

### Step 3: Add Routing Table

Add the routing table to `/etc/iproute2/rt_tables`:

```bash
echo '100 secondary' | sudo tee -a /etc/iproute2/rt_tables
```

### Step 4: Apply Configuration

```bash
sudo netplan apply
```

### Step 5: Verify

Check interface has IP:
```bash
ip addr show enp1s0
```

Check routing policy:
```bash
ip rule show
# Should show: from 10.0.0.94 lookup secondary
```

Check routing table:
```bash
ip route show table secondary
# Should show: default via 10.0.0.1 dev enp1s0
```

Test outbound connectivity:
```bash
curl --interface 10.0.0.94 ifconfig.me
# Should return the secondary public IP (e.g., 203.0.113.x)
```

## Why Policy-Based Routing is Required

Without policy-based routing:

1. Outbound traffic from `10.0.0.94` uses the default route via `enp0s6` (primary NIC)
2. Return traffic arrives on `enp1s0` (secondary NIC)
3. This asymmetric routing causes connection failures

With policy-based routing:

1. Traffic **from** `10.0.0.94` looks up table `100` (secondary)
2. Table `100` has its own default route via `enp1s0`
3. Symmetric routing is maintained

## Note on Oracle's Helper Script

Oracle provides `secondary_vnic_all_configure.sh` for Oracle Linux, but it requires:
- The `oci-utils` package
- An awk helper script (`/usr/libexec/oci_vcn_iface.awk`)

These are not available on Ubuntu. The netplan configuration above is the correct approach for Ubuntu instances.

## Configuration Summary

| Component | Value |
|-----------|-------|
| Interface | `enp1s0` |
| Private IP | `10.0.0.94/24` |
| Public IP | *(assigned by Oracle Cloud)* |
| Gateway | `10.0.0.1` |
| Routing Table | `100` (secondary) |
| Config File | `/etc/netplan/51-secondary-nic.yaml` |

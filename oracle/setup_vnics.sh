#!/usr/bin/env bash

# Setup secondary VNICs on Oracle Cloud Ubuntu instances
# This script queries the metadata service and configures netplan with policy-based routing

set -e

# Check if running on Oracle Cloud
if [ ! -d /etc/oracle-cloud-agent ]; then
    echo "This script is only for Oracle Cloud instances"
    exit 1
fi

# Check for required tools
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Query metadata service for VNIC information
echo "Querying Oracle Cloud metadata service..."
VNICS=$(curl -sH "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/)

if [ -z "$VNICS" ] || [ "$VNICS" == "[]" ]; then
    echo "No VNICs found in metadata"
    exit 1
fi

VNIC_COUNT=$(echo "$VNICS" | jq length)
echo "Found $VNIC_COUNT VNIC(s)"

if [ "$VNIC_COUNT" -lt 2 ]; then
    echo "No secondary VNICs to configure"
    exit 0
fi

# Get primary VNIC MAC (first one is always primary)
PRIMARY_MAC=$(echo "$VNICS" | jq -r '.[0].macAddr' | tr '[:upper:]' '[:lower:]')
echo "Primary VNIC MAC: $PRIMARY_MAC"

# Find gateway from primary interface
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -z "$GATEWAY" ]; then
    echo "Could not determine gateway"
    exit 1
fi
echo "Gateway: $GATEWAY"

# Process secondary VNICs
RT_TABLE_ID=100
for i in $(seq 1 $((VNIC_COUNT - 1))); do
    VNIC=$(echo "$VNICS" | jq ".[$i]")
    MAC=$(echo "$VNIC" | jq -r '.macAddr' | tr '[:upper:]' '[:lower:]')
    PRIVATE_IP=$(echo "$VNIC" | jq -r '.privateIp')
    SUBNET_CIDR=$(echo "$VNIC" | jq -r '.subnetCidrBlock')
    SUBNET_BITS=$(echo "$SUBNET_CIDR" | cut -d'/' -f2)
    VNIC_ID=$(echo "$VNIC" | jq -r '.vnicId')

    echo ""
    echo "Configuring secondary VNIC $i:"
    echo "  MAC: $MAC"
    echo "  Private IP: $PRIVATE_IP"
    echo "  Subnet: $SUBNET_CIDR"

    # Find interface name by MAC
    IFACE=$(ip -o link | grep -i "$MAC" | awk -F': ' '{print $2}')
    if [ -z "$IFACE" ]; then
        echo "  WARNING: Could not find interface for MAC $MAC, skipping"
        continue
    fi
    echo "  Interface: $IFACE"

    # Add routing table if not exists
    RT_NAME="secondary$i"
    if ! grep -q "^$RT_TABLE_ID $RT_NAME" /etc/iproute2/rt_tables 2>/dev/null; then
        echo "$RT_TABLE_ID $RT_NAME" | sudo tee -a /etc/iproute2/rt_tables
        echo "  Added routing table: $RT_TABLE_ID $RT_NAME"
    fi

    # Create netplan config
    NETPLAN_FILE="/etc/netplan/51-secondary-nic-$i.yaml"
    echo "  Creating $NETPLAN_FILE"

    sudo tee "$NETPLAN_FILE" > /dev/null << EOF
network:
  version: 2
  ethernets:
    $IFACE:
      match:
        macaddress: "$MAC"
      addresses:
        - $PRIVATE_IP/$SUBNET_BITS
      set-name: "$IFACE"
      routing-policy:
        - from: $PRIVATE_IP
          table: $RT_TABLE_ID
      routes:
        - to: default
          via: $GATEWAY
          table: $RT_TABLE_ID
EOF

    sudo chmod 600 "$NETPLAN_FILE"
    RT_TABLE_ID=$((RT_TABLE_ID + 1))
done

# Apply netplan
echo ""
echo "Applying netplan configuration..."
sudo netplan apply

# Verify
echo ""
echo "Verification:"
for i in $(seq 1 $((VNIC_COUNT - 1))); do
    VNIC=$(echo "$VNICS" | jq ".[$i]")
    MAC=$(echo "$VNIC" | jq -r '.macAddr' | tr '[:upper:]' '[:lower:]')
    PRIVATE_IP=$(echo "$VNIC" | jq -r '.privateIp')
    IFACE=$(ip -o link | grep -i "$MAC" | awk -F': ' '{print $2}')

    if [ -n "$IFACE" ]; then
        CURRENT_IP=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ "$CURRENT_IP" == "$PRIVATE_IP" ]; then
            echo "  $IFACE: $PRIVATE_IP ✓"
        else
            echo "  $IFACE: expected $PRIVATE_IP, got $CURRENT_IP ✗"
        fi
    fi
done

echo ""
echo "Done! Test with: curl --interface <private-ip> ifconfig.me"

#!/usr/bin/env bash

# Check if the script is running un ubuntu
if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    if [ "$DISTRIB_ID" != "Ubuntu" ]; then
        echo "This script will only work on Ubuntu"
        exit 1
    fi
else
    echo "This script will only work on Ubuntu"
    exit 1
fi

# If docker is not installed
if ! [ -x "$(command -v docker)" ]; then
    # Install docker via https://get.docker.com/
    curl -fsSL https://get.docker.com -o get-docker.sh
    chmod +x get-docker.sh
    ./get-docker.sh
    rm get-docker.sh

    # Install docker-compose
    sudo apt-get install -y docker-compose
fi

# Fix Docker DNS if systemd-resolved is in use (127.0.0.53 doesn't work in containers)
if grep -q "nameserver 127.0.0.53" /etc/resolv.conf 2>/dev/null; then
    if [ ! -f /etc/docker/daemon.json ]; then
        echo "Configuring Docker DNS (systemd-resolved detected)..."
        sudo mkdir -p /etc/docker
        echo '{"dns": ["8.8.8.8", "8.8.4.4"]}' | sudo tee /etc/docker/daemon.json
        sudo systemctl restart docker
    fi
fi

# Select interfaces to run on (Can be multiple)
echo "Please select the interfaces you want to run on"
INTERFACES=$(ls /sys/class/net)
while true; do
    SELECTED_INTERFACES=()
    for INTERFACE in $INTERFACES; do
        read -p "Do you want to run on $INTERFACE? [y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            SELECTED_INTERFACES+=($INTERFACE)
        fi
    done

    # Ensure at least one interface selected
    if [ ${#SELECTED_INTERFACES[@]} -eq 0 ]; then
        echo "You must select at least one interface"
        continue
    fi

    # Confirm selection
    echo "You have selected ${SELECTED_INTERFACES[@]}"
    read -p "Is this correct? [y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break
    fi
done

# Specify a port (default 1080)
read -p "Please enter the port you want to run on [1080]: " DANTE_PORT
if [ -z "$DANTE_PORT" ]; then
    DANTE_PORT=1080
fi

# Set username and password
read -p "Please enter the username [user]: " DANTE_USER
read -p "Please enter the password [random]: " DANTE_PASS
if [ -z "$DANTE_USER" ]; then
    DANTE_USER="user"
fi
if [ -z "$DANTE_PASS" ]; then
    DANTE_PASS=$(openssl rand -base64 12)
fi

#Output these to a file for user to read
echo "Saving credentials to ./credentials.txt"
rm -f ./credentials.txt
echo "Username: $DANTE_USER" >> ./credentials.txt
echo "Password: $DANTE_PASS" >> ./credentials.txt
echo "Socks Port: $DANTE_PORT" >> ./credentials.txt

# If this is an oracle cloud instance (/etc/oracle-cloud-agent/ exists)
if [ -d /etc/oracle-cloud-agent ]; then
    # https://github.com/baunilhaeu/neveridledocker
    # if not cloned, clone it
    if [ ! -d neveridledocker ]; then
        git clone https://github.com/baunilhaeu/neveridledocker neveridledocker
    fi

    # remove existing neveridledocker if it exists
    sudo docker rm -f neveridledocker
    sudo docker build -t neveridledocker neveridledocker
    sudo docker run -d \
        --restart=always \
        --name=neveridledocker \
        --log-driver local \
        --log-opt max-size=10m \
        neveridledocker

    # Add iptables rules if iptables is in use
    if command -v iptables &>/dev/null && sudo iptables -L &>/dev/null; then
        # Find REJECT rule line number to insert before it
        REJECT_LINE=$(sudo iptables -L INPUT --line-numbers -n | grep -i "reject" | head -1 | awk '{print $1}')

        if ! sudo iptables -C INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT 2>/dev/null; then
            if [ -n "$REJECT_LINE" ]; then
                sudo iptables -I INPUT $REJECT_LINE -p tcp --dport 22 -m state --state NEW -j ACCEPT
                REJECT_LINE=$((REJECT_LINE + 1))
            else
                sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT
            fi
        fi
        if ! sudo iptables -C INPUT -p tcp --dport $DANTE_PORT -m state --state NEW -j ACCEPT 2>/dev/null; then
            if [ -n "$REJECT_LINE" ]; then
                sudo iptables -I INPUT $REJECT_LINE -p tcp --dport $DANTE_PORT -m state --state NEW -j ACCEPT
            else
                sudo iptables -A INPUT -p tcp --dport $DANTE_PORT -m state --state NEW -j ACCEPT
            fi
        fi

        # Save iptables rules
        sudo apt-get install -y iptables-persistent
        sudo netfilter-persistent save
    fi
fi

# build the docker image
sudo docker build -t dante .
 
# Ensure existing danted container is removed
sudo docker rm -f dante

# Run the danted container
SELECTED_INTERFACES_STR="${SELECTED_INTERFACES[*]}"
sudo docker run -d \
    --restart=always \
    --name=dante \
    --net=host \
    -e DANTE_USER="$DANTE_USER" \
    -e DANTE_PASS="$DANTE_PASS" \
    -e DANTE_PORT="$DANTE_PORT" \
    -e DANTE_INTERFACES="$SELECTED_INTERFACES_STR" \
    --log-driver local \
    --log-opt max-size=10m \
    dante

# Output the credentials
echo "Username: $DANTE_USER"
echo "Password: $DANTE_PASS"
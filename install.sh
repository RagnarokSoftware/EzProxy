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
read -p "Please enter the username (None for user): " PROXY_USER
read -p "Please enter the password (None for random): " PROXY_PASS
if [ "$PROXY_USER" == "None" ]; then
    PROXY_USER="user"
fi
if [ "$PROXY_PASS" == "None" ]; then
    PROXY_PASS=$(openssl rand -base64 12)
fi

#Output these to a file for user to read
echo "Saving credentials to ./credentials.txt"
rm -f ./credentials.txt
echo "Username: $PROXY_USER" >> ./credentials.txt
echo "Password: $PROXY_PASS" >> ./credentials.txt
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
fi

# build the docker image
sudo docker build -t dante .
 
# Ensure existing danted container is removed
sudo docker rm -f dante

# Run the danted container
SELECTED_INTERFACES_CSV=$(IFS=,; echo "${SELECTED_INTERFACES[*]}")
sudo docker run -d \
    --restart=always \
    --name=dante \
    --net=host \
    -e PROXY_USER=$PROXY_USER \
    -e PROXY_PASS=$PROXY_PASS \
    -e DANTE_PORT=$DANTE_PORT \
    -e DANTE_INTERFACES=$SELECTED_INTERFACES_CSV \
    --log-driver local \
    --log-opt max-size=10m \
    dante

# Output the credentials
echo "Username: $PROXY_USER"
echo "Password: $PROXY_PASS"
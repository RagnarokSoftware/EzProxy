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

# Set username and password
read -p "Please enter the username (None for user): " DANTE_USER
read -p "Please enter the password (None for random): " DANTE_PASS
if [ "$DANTE_USER" == "None" ]; then
    DANTE_USER="user"
fi
if [ "$DANTE_PASS" == "None" ]; then
    DANTE_PASS=$(openssl rand -base64 12)
fi

#Output these to a file for user to read
echo "Saving credentials to ./credentials.txt"
rm -f ./credentials.txt
echo "Username: $DANTE_USER" >> ./credentials.txt
echo "Password: $DANTE_PASS" >> ./credentials.txt

# build the docker image
sudo docker build -t dante .

# Ensure existing danted container is removed
sudo docker rm -f dante

# Run the danted container
SELECTED_INTERFACES=$(IFS=,; echo "${SELECTED_INTERFACES[*]}")
sudo docker run -d \
    --restart=always \
    --name=dante \
    --net=host \
    -e DANTE_USER=$DANTE_USER \
    -e DANTE_PASS=$DANTE_PASS \
    -e DANTE_INTERFACES=$SELECTED_INTERFACES \
    dante

# Output the credentials
echo "Username: $DANTE_USER"
echo "Password: $DANTE_PASS"
#!/usr/bin/env bash

# Ensure $DANTE_USER and $DANTE_PASS are set
if [ -z "$DANTE_USER" ] || [ -z "$DANTE_PASS" ]; then
    echo "Please set the environment variables DANTE_USER and DANTE_PASS"
    exit 1
fi

# Ensure $DANTE_INTERFACES is set
if [ -z "$DANTE_INTERFACES" ]; then
    echo "Please set the environment variable DANTE_INTERFACES"
    exit 1
fi

# Ensure DANTE_PORT is set
if [ -z "$DANTE_PORT" ]; then
    echo "Please set the environment variable DANTE_PORT"
    exit 1
fi

useradd -m -p $(echo $DANTE_PASS | openssl passwd -1 -stdin) -s /bin/bash $DANTE_USER

# Write the configuration file
CONFIG_FILE="/etc/sockd.conf"
rm -f $CONFIG_FILE

cat "socksmethod: username\n" > $CONFIG_FILE
for INTERFACE in $DANTE_INTERFACES; do
    echo "internal: $INTERFACE port = $DANTE_PORT" >> $CONFIG_FILE
done
for INTERFACE in $DANTE_INTERFACES; do
    echo "external: $INTERFACE" >> $CONFIG_FILE
done
echo "external.rotation: same-same" >> $CONFIG_FILE
echo "client pass {" >> $CONFIG_FILE
echo "    from: 0.0.0.0/0 port 1-65535 to: 0.0.0.0/0" >> $CONFIG_FILE
echo "}" >> $CONFIG_FILE
echo "socks pass {" >> $CONFIG_FILE
echo "    from: from: 0.0.0.0/0 port 1-65535 to: 0.0.0.0/0" >> $CONFIG_FILE
echo "    socksmethod: username" >> $CONFIG_FILE
echo "    user $DANTE_USER" >> $CONFIG_FILE
echo "    protocol: tcp udp" >> $CONFIG_FILE
echo "}" >> $CONFIG_FILE

# Start the server
sockd -f $CONFIG_FILE -p /tmp/sockd.pid -N $DANTE_WORKERS
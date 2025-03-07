# Easy Socks dante setup


## Oracle
Remember to add to firewall rules

```
# Flush existing
sudo iptables -F

# Allow all loopback (localhost) traffic
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established and related connections
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow ICMP (ping)
sudo iptables -A INPUT -p icmp -j ACCEPT

# Allow SSH (port 22)
sudo iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT

# Allow NTP (UDP source port ntp)
sudo iptables -A INPUT -p udp --sport ntp -j ACCEPT

# Allow traffic on port 26000
sudo iptables -A INPUT -p tcp --dport 26000 -m state --state NEW -j ACCEPT

# Reject all other traffic
sudo iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited

# Print out the existing
sudo iptables -L -v

# Save
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

You can check the proxy manually by the following command (Works on the instance itself)
`curl --socks5 user:pass@public-ip:port https://icanhazip.com/`
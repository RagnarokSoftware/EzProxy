# Easy Socks dante setup




## Oracle
Remember to add to firewall rules

`-A INPUT -p tcp -m state --state NEW -m tcp --dport 26000 -j ACCEPT`

`sudo iptables-restore < /etc/iptables/rules.v4`
# Easy Socks dante setup

## Oracle Cloud

The install script automatically configures iptables rules for SSH and the SOCKS proxy port on Oracle Cloud instances.

For multiple exit IPs using secondary VNICs, run:
```bash
./oracle/setup_vnics.sh
```

For manual setup details, see [secondary-nic-oracle.md](secondary-nic-oracle.md).

## Testing

```bash
curl --socks5 user:pass@public-ip:port https://icanhazip.com/
```
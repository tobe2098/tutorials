


## Split DNS
Make sure that you either do not set the `DNS` property, or set it limiting the DNS usage to a domain (`~local`). If not, it will not work in Linux.

```
sudo nmcli connection modify wg1 ipv4.dns "10.8.0.1"
sudo nmcli connection modify wg1 ipv4.dns-search "~home"
sudo nmcli connection modify wg1 ipv4.dns-priority -10
```

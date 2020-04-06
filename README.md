# Simple Perl tool to manage ISC-DHCP Server and bind9
## tl;dr
This tool written in perl uses a single YAML file as single-source-of-truth to configure 
* ISC-DHCP Server 
* BIND DNS Server (supports multiple zones)
  * forward records
  * reverse records
* A simple website where all hosts are listed

## Prerequisites
* isc-dhcp-server
  * Must be already configured and running
  * use `include "/etc/dhcp/dhcpd.d/generated.conf";` in your main `dhcpd.conf` file
  * Filename can be changed via variable
* bind9
  * Must be already configured and running
  * replaces `named.conf.local` (zones definition)
* libyaml-libyaml-perl
* apache2/nginx
  * Must be already configured and running

This tool produces 2 HTML pages to be served by any Webserver. Filenames can be changed via variable
* net.html
  * Lists only hosts that have a webservice defined in YAML
* net_all.html 
  * Lists all hosts

## hosts.yml syntax

```yaml
zones:
  [first zone]:
    reverse: [reverse notation of Subnet, e.g. 1.168.192.in-addr.arpa]
  [second zone]:
    reverse: [reverse notation of Subnet, e.g. 1.168.192.in-addr.arpa]
```

For Hosts entries there are several different options. (See basic hosts.yml for examples)

Simple host with DHCP and DNS entry
```yaml
  [hostname]:
    zone: [zone from above]
    ip: [IPv4]
    mac: [MAC address]
```

Simple host with DNS entry (no DHCP)
```yaml
  [hostname]:
    zone: [zone from above]
    ip: [IPv4]
    no_dhcp: true
```

Simple host with DHCP, link-local IPV6 and webservices you want to see on the web page.
```yaml
hosts:
  [hostname]:
    zone: [zone from above]
    ip: [IPv4]
    ipv6: [IPv6]
    web:
      services:
        [service_name]:
          url: "[part behind hostname]"
          mode: [either http or https]
        [service_name]:
          url: "[part behind hostname]"
          mode: [either http or https]
```

## Deploying
Simply run the perl script. hosts.yml is expected to be in the same directory
```
sudo perl config.pl
```

## Example
With the host.yml in this repo, this is what you'll get:

### DNS
* Zone: internal.lan
  * matching reverse zone 1.168.192.in-addr.arpa (for 192.168.1.0/24)
* Zone: iot.internal.lan
  * matching reverse zone 2.168.192.in-addr.arpa (for 192.168.2.0/24)

### DHCP
* host `server`
  * No DHCP config (since it is the dhcp server)
  * `server.internal.lan` A record for 192.168.1.2
  * `server.internal.lan` AAAA record for IPv6
  * PTR record for 192.168.1.2
  * Website entries
    * PLEX: `http://server.internal.lan:32400/web`
    * Grafana `http://server.internal.lan:3000`
* host `brother`
  * DHCP config with fixed address for given mac
  * `brother.internal.lan` A record for 192.168.1.3
  * PTR record for 192.168.1.3
  * Website entries
    * Frontend: `http://brother.internal.lan/`
* host `hue`
  * DHCP config with fixed address for given mac
  * `hue.iot.internal.lan` A record for 192.168.1.4
  * PTR record for 192.168.1.4

### Website
Only Hosts with services:<br>
<img src=service_hosts.jpg border="10" width="50%" height="50%"></img>

All Hosts:<br>
<img src=all_hosts.jpg border="10" width="50%" height="50%"></img>

## Limitations
If you're using VLAN's to seperate subnets (e.g. IoT in this example): Please configure your DHCP server, so it accepts a single included file with fixed address in multiple subnets.

In my case: Main VLAN is served by this isc-dhcp. All other VLAN's are served by my router. 

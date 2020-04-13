# Simple Perl tool to manage ISC-DHCP Server and bind9
## tl;dr
This tool written in perl uses a single YAML file as single-source-of-truth to configure 
* ISC-DHCP Server 
* BIND DNS Server (supports multiple zones)
  * forward records
  * reverse records
* A simple website using bootstrap where all hosts are listed

## Disclaimer
* No real error handling :-)
* Bootstrap includes are expected to be in `$HTML_ROOT/bootstrap/`


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

## hosts.yaml syntax
```yaml
zones:
  internal.lan:
    reverse: [reverse notation of Subnet, e.g. 1.168.192.in-addr.arpa]
    subnet: 192.168.1.0/24 # subnet cidr
    description: Main Network # simple description
    expanded: "true" # "true" or "false". controls whether navbar is expanded by default. quotation marks needed
    hosts:
      server: # hostname
        ip: 192.168.1.2
        ipv6: fe80::ec4:7aff:fe95:e4ca
        no_dhcp: true # whether DHCPd config is needed
        web: # webservices you want to see on the web page
          services:
            PLEX: # service name
              url: ":32400/web" # part behind hostname
              mode: http # http or https
            Grafana:
              url: ":3000"
              mode: http
      brother:
        ip: 192.168.1.3
        mac: 3c:2a:f4:c9:5a:a9
        web:
          services:
            Frontend:
              url: "/"
              mode: https
  iot.internal.lan:
    reverse: 2.168.192.in-addr.arpa
    expanded: "false"
    subnet: 192.168.2.0/24
    description: IoT Devices
    hosts:
      hue:
        ip: 192.168.2.2
        mac: 7c:2f:90:af:b3:4e
```

For Hosts entries there are several different options. (See basic hosts.yml for examples). You can specify as many as you need under each zone.

Simple host with DHCP and DNS entry
```yaml
hosts:
  [hostname]:
    ip: [IPv4]
    mac: [MAC address]
```

Simple host with DNS entry (no DHCP)
```yaml
hosts:
  [hostname]:
    ip: [IPv4]
    no_dhcp: true
```

Simple host with DHCP, link-local IPV6 and webservices you want to see on the web page.
```yaml
hosts:
[hostname]:
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
With the host.yml in this repo you'll get:

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

## Limitations
If you're using VLAN's to seperate subnets (e.g. IoT in this example): Please configure your DHCP server, so it accepts a single included file with fixed address in multiple subnets.

In my case: Main VLAN is served by this isc-dhcp. All other VLAN's are served by my router. 
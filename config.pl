#!/usr/bin/perl

use warnings;
use strict;

use YAML::XS 'LoadFile';
my $config = LoadFile('hosts.yml');

# GLOBAL FILES/FOLDERS CONFIG
my $dhcpconf = "/etc/dhcp/dhcpd.d/generated.conf"; #desired dhcpd config file to be included
my $bind_conf_folder = "/etc/bind/"; #default folder for bind9 configs
my $website_dir = "/var/www/html"; #Folder where your site index is
my $page = "net.html"; #website filename for hosts with services
my $page_all = "net_all.html"; #website filename for all hosts

# OTHER VARS
my $hostname = "server.internal.lan"; #Hostname of server running dhcp/bind
my $website_title = "Network overview for internal.lan"; #Title of the Website
my $webserver = "https://$hostname";
my $website = "$website_dir/$page";
my $website_html_all = "$website_dir/$page_all";

# HTML TABLE FORMATTING
my $table_style = "<style>table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
}
tr:nth-child(even) {background-color: #f2f2f2;}
</style>";
my $table_width_total = 550;
my $table_hostname_width = 250;
my $table_ip_width = 200;
my $table_services_width = 100;

##### DHCP START ######
printf "--- DHCP CONFIG ---\n";
open(DHCP, '>', $dhcpconf) or die $!;
print DHCP "group {\n
use-host-decl-names on;\n";
for (sort keys %{$config->{hosts}}) {
    unless ($config->{hosts}->{$_}->{no_dhcp}) {
        printf "Set DHCP [$_]\n";
        print DHCP "host $_ {
            hardware ethernet $config->{hosts}->{$_}->{mac};
            fixed-address $config->{hosts}->{$_}->{ip};
        }\n";
    }
}
print DHCP "}\n";
close(DHCP);
printf "\n\n";
##### DHCP END ######


##### DNS START ######
printf "--- DNS CONFIG ---\n";

#named.conf.local
open(named_conf, '>', "$bind_conf_folder/named.conf.local") or die $!;
for (sort keys %{$config->{zones}}) { # Create forward zone file entries for each zone
    print named_conf "zone $_ {
        type master;
        file \"$bind_conf_folder/db.$_\";
};\n";
}
for (sort keys %{$config->{zones}}) { # Create reverse zone file entries for each zone
    print named_conf "zone $config->{zones}->{$_}->{reverse} {
        type master;
        file \"$bind_conf_folder/db.$config->{zones}->{$_}->{reverse}\";
};\n";
}
close(named_conf);

#reverse records
printf "--- DNS REVERSE RECORDS ---\n";
for (sort keys %{$config->{zones}}) { # Iterate over all zones
    printf "--- ZONE [$_] ---\n";
    open(PTR, '>', "$bind_conf_folder/db.$config->{zones}->{$_}->{reverse}") or die $!; 
    print PTR "
\$TTL    604800
@       IN      SOA     $hostname. root.localhost. (
                        1
                        604800
                        86400
                        2419200
                        604800 )
;
@       IN      NS      $hostname.
";
    my $tempfwdzone = $_; # save current temp forward zone for later
    for (sort keys %{$config->{hosts}}) {
            if ("$config->{hosts}->{$_}->{zone}" eq "$tempfwdzone") { # Print only if zone of current host eqals the current forward zone
                my $last = ( split /[.]/, $config->{hosts}->{$_}->{ip} )[-1]; # extract last octet of ip address
                printf "Set PTR record for [$_.$config->{hosts}->{$_}->{zone}]\n";
                print PTR "$last\tIN\tPTR\t$_.$config->{hosts}->{$_}->{zone}.\n";
            }

        }
        close(PTR);
        printf "\n\n";
}
printf "\n";

#forward records
printf "--- DNS FORWARD RECORDS ---\n";
for (sort keys %{$config->{zones}}) { # Iterate over all zones
    printf "--- ZONE [$_] ---\n";
    open(FWD, '>', "$bind_conf_folder/db.$_") or die $!;
    print FWD "
\$TTL    604800
@       IN      SOA     $hostname. root.localhost. (
                    1
                    604800
                    86400
                    2419200
                    604800 )
;
@       IN      NS      $hostname.
";
     my $tempfwdzone = $_; # save current temp forward zone for later
    for (sort keys %{$config->{hosts}}) {
        if ("$config->{hosts}->{$_}->{zone}" eq "$tempfwdzone") { # Print only if zone of current host eqals the current forward zone
            print FWD "$_\tIN\tA\t$config->{hosts}->{$_}->{ip}\n";
            printf "Set A record for [$_.$config->{hosts}->{$_}->{zone}]\n";
            if ($config->{hosts}->{$_}->{ipv6}) { # Print only if AAAA record is set
                print FWD "$_\tIN\tAAAA\t$config->{hosts}->{$_}->{ipv6}\n";
                printf "Set AAAA record for [$_.$config->{hosts}->{$_}->{zone}]\n";
            }
        }
    }
    close(FWD);
    printf "\n\n";
}
printf "\n\n";
##### DNS END ######


##### WEBSITE START ######
open(website_html, '>', $website) or die $!;
open(website_html_all, '>', $website_html_all) or die $!;

#Website header
my $fh;
for $fh (*website_html, *website_html_all) { 
    print $fh "<html>
<head>
<title>Network overview</title>
</head>
$table_style
<body>
<h1>$website_title</h1>";
}

#different link for each site
print website_html "<a href=$webserver/$page_all>Show all hosts</a>";
print website_html_all "<a href=$webserver/$page>Show only hosts with services</a>";

for (sort keys %{$config->{zones}}) { # Iterate over all zones (to sort website by zone)
    my $tempzone = $_; # save the current zone for later
    for $fh (*website_html, *website_html_all) { print $fh "<h2>Zone: [$_]</h2><table width=\"$table_width_total\">
<tr><th width=\"$table_hostname_width\">Device</th><th width=\"$table_ip_width\">IP</th><th width=\"$table_services_width\">Services</th></tr>" }
    for (sort keys %{$config->{hosts}}) { # Iterate over all hosts
        if ("$config->{hosts}->{$_}->{zone}" eq "$tempzone"){ # Print only if zone of current host eqals the current zone
            my $temp_device = $_ . '.' . $config->{hosts}->{$_}->{zone}; # Save fqdn into variable
            my $temp_host = $_; # Save current host for later
            
            #Print only hosts with services to main site
            print website_html "<tr><td>$_</td><td>$config->{hosts}->{$_}->{ip}</td><td>" if $config->{hosts}->{$_}->{web};
            print website_html_all "<tr><td>$_</td><td>$config->{hosts}->{$_}->{ip}</td><td>";

            for (sort keys %{$config->{hosts}->{$_}->{web}->{services}}) { # Iterate over all Hosts that have a services entry
                my $final_url = $config->{hosts}->{$temp_host}->{web}->{services}->{$_}->{mode} . '://' . $temp_device . $config->{hosts}->{$temp_host}->{web}->{services}->{$_}->{url};
                for $fh (*website_html, *website_html_all) { print $fh "<a href=$final_url target=_blank>$_</a><br>" }
            }
        }
    }
    for $fh (*website_html, *website_html_all) { print $fh "</table>" }
}
for $fh (*website_html, *website_html_all) { print $fh "</body></html>" }
close(website_html);
close(website_html_all);
##### WEBSITE END ######

#Restart Stuff
printf "--- Restarting DHCP and DNS Server ---\n";
system("service bind9 reload");
system("service isc-dhcp-server restart");

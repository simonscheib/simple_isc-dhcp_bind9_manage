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
my $datestring = localtime();

##### DHCP START ######
printf "--- DHCP CONFIG ---\n";
open(DHCP, '>', $dhcpconf) or die $!;
print DHCP "group {\n
use-host-decl-names on;\n";

for (sort keys %{$config->{zones}}) {
    my $tempzone = $_;
    print "Reading Hosts in Zone [$tempzone]\n";
    for (sort keys %{$config->{zones}->{$_}->{hosts}}) {
        unless ($config->{zones}->{$tempzone}->{hosts}->{$_}->{no_dhcp}) {
            printf "Set DHCP [$_]\n";
            print DHCP "host $_ {
                hardware ethernet $config->{zones}->{$tempzone}->{hosts}->{$_}->{mac};
                fixed-address $config->{zones}->{$tempzone}->{hosts}->{$_}->{ip};
            }\n";
        }
    }
}

print DHCP "}\n";
close(DHCP);
printf "\n\n";
##### DHCP END ######

# ##### DNS START ######
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
    for (sort keys %{$config->{zones}->{$tempfwdzone}->{hosts}}) {
        my $last = ( split /[.]/, $config->{zones}->{$tempfwdzone}->{hosts}->{$_}->{ip} )[-1]; # extract last octet of ip address
        printf "Set PTR record for [$_.$tempfwdzone]\n";
        print PTR "$last\tIN\tPTR\t$_.$tempfwdzone.\n";
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
    for (sort keys %{$config->{zones}->{$tempfwdzone}->{hosts}}) {
        print FWD "$_\tIN\tA\t$config->{zones}->{$tempfwdzone}->{hosts}->{$_}->{ip}\n";
        printf "Set A record for [$_.$tempfwdzone]\n";
        if ($config->{zones}->{$tempfwdzone}->{hosts}->{$_}->{ipv6}) { # Print only if AAAA record is set
            print FWD "$_\tIN\tAAAA\t$config->{zones}->{$tempfwdzone}->{hosts}->{$_}->{ipv6}\n";
            printf "Set AAAA record for [$_.$tempfwdzone]\n";
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
    print $fh "<!doctype html>
<html lang=\"en\">
  <head>
    <meta charset=\"utf-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1, shrink-to-fit=no\">
    <link rel=\"stylesheet\" href=\"bootstrap/bootstrap.min.css\" integrity=\"sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh\" crossorigin=\"anonymous\">
    <title>Network overview</title>
  </head>
  <body>
    <nav class=\"navbar navbar-light bg-primary\">
        <a class=\"navbar-brand\"><img src=\"network-connection.svg\" width=\"30\" height=\"30\" class=\"d-inline-block align-top\" alt=\"\"> $website_title</a>
        <button class=\"navbar-toggler\" type=\"button\" data-toggle=\"collapse\" data-target=\"#navbarSupportedContent\" aria-controls=\"navbarSupportedContent\" aria-expanded=\"true\" aria-label=\"Toggle navigation\">
            <span class=\"navbar-toggler-icon\"></span>
        </button>
        <div class=\"collapse navbar-collapse\" id=\"navbarSupportedContent\">
            <ul class=\"navbar-nav mr-auto\">
                <li class=\"nav-item\">
                    <a class=\"nav-link\" href=\"net.html\">Selected Hosts</a>
                </li>
                <li class=\"nav-item \">
                    <a class=\"nav-link\" href=\"net_all.html\">All Hosts</a>
                </li>
            </ul>
        </div>
    </nav>
    <div class=\"accordion\" id=\"accordionExample\">"
}

for (sort keys %{$config->{zones}}) { # Iterate over all zones (to sort website by zone)
    my $tempzone = $_; # save the current zone for later
    
    my $tempzone_id = $tempzone;
    $tempzone_id =~ s/\.//;
    $tempzone_id =~ s/\.//; # remove all dots of zone name for use as id's for bootstrap
    
    my $ariaclass;
    if ("$config->{zones}->{$tempzone}->{expanded}" eq "true" ) { 
        $ariaclass = "collapse show";
    } else { 
        $ariaclass = "collapse";
    }
    print "Processing website entry for Zone [$tempzone]\n";

    my $count_hosts = keys %{$config->{zones}->{$tempzone}->{hosts}};

    for $fh (*website_html, *website_html_all) { print $fh "
        <div class=\"card\">
            <div class=\"card-header\" id=\"heading$tempzone_id\">
                <h2 class=\"mb-0\">
                    <button class=\"btn btn-link\" type=\"button\" data-toggle=\"collapse\" data-target=\"#$tempzone_id\" aria-expanded=\"$config->{zones}->{$tempzone}->{expanded}\" aria-controls=\"$tempzone_id\">
                        <strong>$_</strong> <span class=\"badge badge-pill badge-secondary\">$count_hosts</span> <span class=\"badge badge-pill badge-secondary\">$config->{zones}->{$tempzone}->{subnet}</span>
                    </button>
                </h2>
            </div>
            <div id=\"$tempzone_id\" class=\"$ariaclass\" aria-labelledby=\"heading$tempzone_id\" data-parent=\"#accordionExample\">
                <div class=\"card-body\">
                <p><span class=\"badge badge-pill badge-secondary\">$config->{zones}->{$tempzone}->{description}</span></p>
                <table class=\"table table-striped\" >
                    <thead>
                        <tr>
                            <th scope=\"col\">Device</th>
                            <th scope=\"col\">IP</th>
                            <th scope=\"col\">Services</th>
                        </tr>
                    </thead>
                <tbody>";
    }

    for (sort keys %{$config->{zones}->{$tempzone}->{hosts}}) { # Iterate over all hosts
        my $temp_device = $_ . '.' . $tempzone; # Save fqdn into variable
        my $temp_host = $_; # Save current host for later
        
        #Print only hosts with services to main site
        print website_html "
        <tr>
            <th scope=\"row\">$_</th>
            <td>$config->{zones}->{$tempzone}->{hosts}->{$_}->{ip}</td>
            <td>" if $config->{zones}->{$tempzone}->{hosts}->{$_}->{web};
        print website_html_all "
        <tr>
            <th scope=\"row\">$_</th>
            <td>$config->{zones}->{$tempzone}->{hosts}->{$_}->{ip}</td>
            <td>";

        for (sort keys %{$config->{zones}->{$tempzone}->{hosts}->{$_}->{web}->{services}}) { # Iterate over all Hosts that have a services entry
            my $final_url = $config->{zones}->{$tempzone}->{hosts}->{$temp_host}->{web}->{services}->{$_}->{mode} . '://' . $temp_device . $config->{zones}->{$tempzone}->{hosts}->{$temp_host}->{web}->{services}->{$_}->{url};
            for $fh (*website_html, *website_html_all) { print $fh "<a href=$final_url target=_blank>$_</a><br>" }
        }
    }
    for $fh (*website_html, *website_html_all) { 
        print $fh "
            </tbody>
        </table>
        </div>
        </div>
        </div>
        " 
    }
}
for $fh (*website_html, *website_html_all) { print $fh "
    <div class=\"footer-copyright text-center py-3\">Last updated: $datestring</div>
    <script src=\"bootstrap/jquery-3.4.1.slim.min.js\" integrity=\"sha384-J6qa4849blE2+poT4WnyKhv5vZF5SrPo0iEjwBvKU7imGFAV0wwj1yYfoRSJoZ+n\" crossorigin=\"anonymous\"></script>
    <script src=\"bootstrap/popper.min.js\" integrity=\"sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo\" crossorigin=\"anonymous\"></script>
    <script src=\"bootstrap/bootstrap.min.js\" integrity=\"sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6\" crossorigin=\"anonymous\"></script>
  </body>
</html>" }
close(website_html);
close(website_html_all);
##### WEBSITE END ######

#Restart Stuff
printf "--- Restarting DHCP and DNS Server ---\n";
system("service bind9 reload");
system("service isc-dhcp-server restart");

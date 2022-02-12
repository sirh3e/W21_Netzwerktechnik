# Raspberry Pi Firewall with ipTables

## Initial situation
During an internship at the TEKO school, the establishment of a network was put into practice. This consisted of two firewalls, a web proxy, a DNS server, a radius and DHCP server as well as 3 access points. Our task was to set up two Raspberry Pi's as a firewall.

## Hardware configuration

Since the Pi's are on factory settings, the hostnames must still be adjusted, otherwise no identification in the network can be guaranteed. an ssh access would be impossible with identical hostnames, if one uses the syntax user@hostname.

That can be just fine. 2 servers so requests are sent round robin to them. Most extreme example www.google.com are many many servers.

Of course there is a second mechanism so maintenance can adress a specific server individual.

We change the hostname as follows:

```
$ sudo hostname 0xdeadcode0
```

And for the second Pi:

```
$ sudo hostname 0xdeadcode1
```

We use 2 RPi's Model 3B. Since these devices only had one LAN (RJ-45) port, we used additional LAN ports via USB 3.0.

However, this must be configured correctly as a new ethernet port. To do this please open the following configuration with sudo right.
```
$ sudo nvim /etc/network/interfaces
```

We can configure this device to have a fixed address (this makes it easier to find on our TEKO-Lab network!)

```
allow-hotplug usb0
iface usb02 inet static
        address 10.0.0.2
        netmask 255.0.0.0
        broadcast 10.255.255.255
        gateway 10.0.0.1
```
We configure the onBoard Ethernet port according to the network diagram as follows.

```
allow-hotplug eth0
iface eth0 inet static
        address 172.16.1.1
        netmask 255.255.0.0
        broadcast 172.16.255.255
        gateway 10.0.0.1
```

Save the file (:wq) and run


```
$ sudo ifdown usb0 #this may fail, its fine
```
```
$ sudo ifdown eth0 #this may fail, its fine
```
```
$ sudo ifup usb0
```
```
$ sudo ifup eth0
```
```
$ ifconfig
```

The executed commands restart the interfaces service and apply the configuration

Our Rasperry PI's now has two fully functional ethernet ports and is ready to be configured as a firewall.

---

## Preparations
For the Raspberry Pi, the firewall iptables is already on board, but not configured. If you have your single board computer directly connected to the internet, you should enable the firewall to increase the protection of the system. In the following an example configuration for a statefull firewall is shown. This may vary depending on the intended use and in no way claims to be complete. It is advisable to keep a current backup in order to quickly return to the original state in a worst-case scenario.


The first step is to create a configuration directory for iptables.

```
$ sudo mkdir /etc/iptables
```

The actual firewall rules are later located in the file "/etc/iptables/iptables.rules" for IPv4 or "/etc/iptables/ip6tables.rules" for IPv6. To initialize the firewall, the following commands can be copied into a script that must be executed. The script takes into account both IPv4 and IPv6 iptables statefull firewall. Explanations of the individual commands are stored as comments in the script. In our internship, however, only IPv4 was relevant

**Please note the following**

- The following steps are all purely theoretical and could not be carried out during the internship due to lack of time.
- The written instructions are based on manuals, research and own experience. Sources can be found at the end of the document

The following open-source script was used as a reference and adapted to our needs.

>https://gist.github.com/heartnet/921615

```
#!/bin/bash

# flush all existing chains and delete non default-chains
iptables -F
iptables -X
ip6tables -F
ip6tables -X

# custom chains
iptables -N TCP_IN
iptables -N UDP_IN
ip6tables -N TCP_IN
ip6tables -N UDP_IN

# FORWARD, OUTPUT and INPUT chain
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT
ip6tables -P INPUT DROP

# allow existing established connections for INPUT and OUTPUT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# allow loopback interface for INPUT and OUTPUT
iptables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT**

# drop invalid packages
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
ip6tables -A INPUT -m conntrack --ctstate INVALID -j DROP

# ICMP
iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
ip6tables -A INPUT -p icmpv6 --icmpv6-type 128 -m conntrack --ctstate NEW -j ACCEPT

# DHCPv6
ip6tables -A INPUT -s fe80::/10 -j ACCEPT
ip6tables -A OUTPUT -s fe80::/10 -j ACCEPT

# set TCP_IN and UDP_IN chain as INPUT chain 
iptables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP_IN
iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP_IN
ip6tables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP_IN
ip6tables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP_IN

# reject incomming connections if ports are not opened
iptables -A INPUT -p udp -m recent --set --rsource --name UDP-PORTSCAN -j REJECT --reject-with icmp-port-unreachable
iptables -A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -A INPUT -p tcp -j REJECT --reject-with tcp-reset
ip6tables -A INPUT -p udp -j REJECT --reject-with icmp6-port-unreachable
ip6tables -A INPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -A INPUT -j REJECT --reject-with icmp-proto-unreachable
ip6tables -A INPUT -j REJECT

# allow incomming traffic
iptables -A TCP_IN -p tcp --dport 22 -j ACCEPT
iptables -A TCP_IN -p tcp --dport 80 -j ACCEPT
iptables -A TCP_IN -p tcp --dport 443 -j ACCEPT
ip6tables -A TCP_IN -p tcp --dport 22 -j ACCEPT
ip6tables -A TCP_IN -p tcp --dport 80 -j ACCEPT
ip6tables -A TCP_IN -p tcp --dport 443 -j ACCEPT

# save the firewall rules
iptables-save > /etc/iptables/iptables.rules
ip6tables-save > /etc/iptables/ip6tables.rules
```
The generated script must still be made executable.


```
$ sudo chmod +x /usr/local/bin/iptables.sh
```

To set the new firewall rules and save them permanently, the script is executed.

```
$ sudo sh /usr/local/bin/iptables.sh
```

To ensure that the changes made persist after a reboot, the iptables and ip6tables services are enabled and started to start the firewall.

```
$ sudo systemctl enable iptables 
```

```
$ sudo systemctl start iptables 
```

To check the status of the firewall, the services can be queried.

```
$ systemctl status iptables ip6tables
```

The firewall is configured with this and should do its job from now on.

## Quintessence
Unfortunately, the project could not be completed. The reasons were many and varied. Primarily, there was too little time available. However, we really enjoyed the opportunity to physically come to the school again and experience a professional exchange.
## Sources

* https://blog.onetwentyseven001.com/iptables-security-part-ii/index.html
* https://piprojects.us/iptables-firewall-rules-for-your-pi/
* https://man7.org/linux/man-pages/man8/iptables.8.html
* Exchanges with fellow students
* Expertises by Andreas Holzer

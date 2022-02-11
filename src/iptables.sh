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
ip6tables -A INPUT -i lo -j ACCEPT

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
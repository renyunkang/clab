interfaces {
    bridge br0 {
        address 10.10.0.1/24
        description leaf1-br
        member {
            interface eth11 {
            }
            interface eth12 {
            }
            interface eth13 {
            }
        }
    }
    loopback lo {
    }
}
protocols {
    bgp {
        address-family {
            ipv4-unicast {
                network 10.10.0.0/24 {
                }
                network 10.10.10.0/24 {
                }
                network 10.10.11.0/24 {
                }
            }
        }
        local-as 65005
        neighbor 10.1.10.2 {
            remote-as 500
        }
        neighbor 10.1.12.2 {
            remote-as 800
        }
        neighbor 10.10.0.3 {
            remote-as 65000
        }
        neighbor 10.10.0.4 {
            remote-as 65000
        }
        parameters {
            bestpath {
                as-path {
                    multipath-relax
                }
            }
            router-id 10.10.0.1
        }
    }
    static {
        route 0.0.0.0/0 {
            next-hop 10.1.10.2 {
            }
            next-hop 10.1.12.2 {
            }
        }
        route 10.1.11.0/24 {
            next-hop 10.1.12.2 {
            }
        }
        route 10.1.34.0/24 {
            next-hop 10.1.10.2 {
            }
        }
    }
}
system {
    config-management {
        commit-revisions 100
    }
    console {
        device ttyS0 {
            speed 115200
        }
    }
    host-name vyos
    login {
        user vyos {
            authentication {
                encrypted-password $6$QxPS.uk6mfo$9QBSo8u1FkH16gMyAVhus6fU3LOzvLR9Z9.82m3tiHFAxTtIkhaZSWssSgzt4v4dGAL8rhVQxTg0oAG9/q11h/
                plaintext-password ""
            }
        }
    }
    ntp {
        server time1.vyos.net {
        }
        server time2.vyos.net {
        }
        server time3.vyos.net {
        }
    }
    syslog {
        global {
            facility all {
                level info
            }
            facility protocols {
                level debug
            }
        }
    }
}


// Warning: Do not remove the following line.
// vyos-config-version: "bgp@1:broadcast-relay@1:cluster@1:config-management@1:conntrack@2:conntrack-sync@2:dhcp-relay@2:dhcp-server@5:dhcpv6-server@1:dns-forwarding@3:firewall@5:https@2:interfaces@20:ipoe-server@1:isis@1:l2tp@3:lldp@1:mdns@1:nat@5:nat66@1:ntp@1:pppoe-server@5:pptp@2:qos@1:quagga@9:rpki@1:salt@1:snmp@2:ssh@2:sstp@3:system@21:vrf@2:vrrp@2:vyos-accel-ppp@2:wanloadbalance@3:webproxy@2:zone-policy@1"
// Release version: 1.4-rolling-202106011750

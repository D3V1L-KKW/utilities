#!/bin/bash
# version 1

if [ $# -ne 3 ]; then
     echo "Usage: ./dns_server.sh 192.168.1.14 domain.com sub"
     exit 1
fi

HOSTIP=$1
DNSNAME=$2
SUB=$3
TMP_DIR=$(mktemp -d -t dns-XXXXXX)
REV_IP=$(echo $HOSTIP |  awk -F. '{print $3"." $2"."$1}')
END_IP=$(echo $HOSTIP |  awk -F. '{print $4}')

sudo apt-get update
sudo apt-get install -y bind9 bind9utils bind9-doc dnsutils

echo "[+] Configuring named.conf file"
cat <<EOF > $TMP_DIR/named.conf
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";

zone "$DNSNAME" IN { //Domain name
     type master; //Primary DNS
     file "/etc/bind/forward.$DNSNAME.domain"; //Forward lookup file
};

zone "$REV_IP.in-addr.arpa" IN { //Reverse lookup name, should match your network in reverse order
     type master; // Primary DNS
     file "/etc/bind/reverse.$DNSNAME.ip"; //Reverse lookup file
};
EOF
sleep 1

echo "[+] Creating Forward DNS"
cat <<EOF > $TMP_DIR/forward.$DNSNAME.domain
;
; BIND data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     $DNSNAME. root.$DNSNAME. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;s
@       IN      NS      $DNSNAME.
@       IN      A       $HOSTIP
$SUB     IN      A       $HOSTIP
EOF
sleep 1

echo "[+] Creating Reverse DNS"
cat <<EOF > $TMP_DIR/reverse.$DNSNAME.ip
;
; BIND reverse data file for local loopback interface
;
\$TTL    604800
@       IN      SOA     $DNSNAME. root.$DNSNAME. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.
$END_IP     IN      PTR      www.$DNSNAME.
$END_IP     IN      PTR     $SUB.$DNSNAME.

EOF
sleep 1
echo "[+] Setting up configuration files"
sudo mv $TMP_DIR/* /etc/bind/
sleep 1
echo "[+] Restarting DNS Server"
sudo systemctl restart bind9
sleep 1
echo "[+] Finished"
sudo systemctl status bind9



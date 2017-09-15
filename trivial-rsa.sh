#!/bin/sh
# Written by Ryan Castellucci, no rights reserved
# Relased under Creative Commons CC0 1.0 Universal

set -e

# Knobs you might want to adjust but probably shouldn't
DAYS=36524
DH_BITS=2048
RSA_BITS=2048

RAMDISK=/dev/shm

# 16 random hex characters each
CA_ID=`head -c8 /dev/urandom | xxd -p`
SRV_ID=`head -c8 /dev/urandom | xxd -p`
CLI_ID=`head -c8 /dev/urandom | xxd -p`

BASEDIR=`mktemp -dtp "$RAMDISK" trivial-rsa-XXXXXXXXXX`

DIR="$BASEDIR/tls-$CA_ID"

mkdir "$DIR"

cat > "$DIR/ext.cnf" <<EoF
[ca]
basicConstraints       = critical,CA:TRUE,pathlen:0
nsCertType             = sslCA
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer:always
extendedKeyUsage       = clientAuth,serverAuth
keyUsage               = critical,keyCertSign

[cli]
basicConstraints       = critical,CA:FALSE
nsCertType             = client
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage       = clientAuth
keyUsage               = critical,digitalSignature,keyAgreement

[srv]
basicConstraints       = critical,CA:FALSE
nsCertType             = server
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage       = serverAuth
keyUsage               = critical,digitalSignature,keyAgreement
EoF

# Generate CA key and certificate
openssl req -new -newkey rsa:$RSA_BITS \
            -nodes -keyout "$DIR/ca.key" -out "$DIR/ca.req" -sha256 \
            -batch -subj /CN=$CA_ID

openssl x509 -req -days $DAYS \
             -signkey "$DIR/ca.key" -in "$DIR/ca.req" -out "$DIR/ca.crt" \
             -extfile "$DIR/ext.cnf" -extensions ca -set_serial 0x$CA_ID

# Generate server key and certificate
openssl req -new -newkey rsa:$RSA_BITS \
            -nodes -keyout "$DIR/srv.key" -out "$DIR/srv.req" -sha256 \
            -batch -subj /CN=$SRV_ID

openssl x509 -req -CA "$DIR/ca.crt" -CAkey "$DIR/ca.key" -days $DAYS \
             -in "$DIR/srv.req" -out "$DIR/srv.crt" \
             -extfile $DIR/ext.cnf -extensions srv -set_serial 0x$SRV_ID

# Generate client key and certificate
openssl req -new -newkey rsa:$RSA_BITS \
            -nodes -keyout "$DIR/cli.key" -out "$DIR/cli.req" -sha256 \
            -batch -subj /CN=$SRV_ID

openssl x509 -req -CA "$DIR/ca.crt" -CAkey "$DIR/ca.key" -days $DAYS \
             -in "$DIR/cli.req" -out "$DIR/cli.crt" \
             -extfile "$DIR/ext.cnf" -extensions cli -set_serial 0x$CLI_ID

openssl dhparam -out "$DIR/dh$DH_BITS.pem" $DH_BITS

openvpn --genkey --secret "$DIR/ta.key"

cat > "$BASEDIR"/server-$CA_ID.conf <<EoF
proto udp
port XXXXX
;remote XXX.YYY.ZZZ

dev vpnXX
dev-type tun

verb 3

user openvpn
group nogroup

ping 5
ping-restart 30
ping-timer-rem

float
multihome
resolv-retry infinite

; ulimit needs to be adjusted to used mlock
;mlock
persist-tun
persist-key

reneg-sec 3600

auth SHA256
; AES-128-GCM requries OpenVPN 2.4 or higher
cipher AES-128-GCM
;cipher AES-128-CBC

####################
# BEGIN TLS CONFIG #
####################
tls-server

ca tls-$CA_ID/ca.crt
key tls-$CA_ID/srv.key
cert tls-$CA_ID/srv.crt
dh tls-$CA_ID/dh$DH_BITS.pem

; ns-cert-type will be removed in OpenVPN 2.5
;ns-cert-type client

; remote-cert-tls requires OpenVPN 2.1 or higher
remote-cert-tls client

; tls-auth config for older OpenVPN
;key-direction 0
;tls-auth tls-$CA_ID/ta.key

; tls-crypt requires OpenVPN 2.4 or higher
tls-crypt tls-$CA_ID/ta.key

# ecdh-curve requires OpenVPN 2.4 or higher
echd-curve secp521r1

tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-256-CBC-SHA
####################
#  END TLS CONFIG  #
####################
EoF

cat > "$BASEDIR"/client-$CA_ID.conf <<EoF
proto udp
port XXXXX
remote XXX.YYY.ZZZ

dev vpnXX
dev-type tun

verb 3

user openvpn
group nogroup

ping 5
ping-restart 30
;ping-timer-rem

float
multihome
resolv-retry infinite

; ulimit needs to be adjusted to used mlock
;mlock
persist-tun
persist-key

reneg-sec 3600

auth SHA256
; AES-128-GCM requries OpenVPN 2.4 or higher
cipher AES-128-GCM
;cipher AES-128-CBC

####################
# BEGIN TLS CONFIG #
####################
tls-client

ca tls-$CA_ID/ca.crt
key tls-$CA_ID/cli.key
cert tls-$CA_ID/cli.crt
dh tls-$CA_ID/dh$DH_BITS.pem

; ns-cert-type will be removed in OpenVPN 2.5
;ns-cert-type server

; remote-cert-tls requires OpenVPN 2.1 or higher
remote-cert-tls server

; tls-auth config for older OpenVPN
;key-direction 1
;tls-auth tls-$CA_ID/ta.key

; tls-crypt requires OpenVPN 2.4 or higher
tls-crypt tls-$CA_ID/ta.key

; ecdh-curve requires OpenVPN 2.4 or higher
echd-curve secp521r1

tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-256-CBC-SHA
####################
#  END TLS CONFIG  #
####################
EoF

chmod 400 "$DIR"/*.key 
chmod 444 "$DIR"/*.pem
chmod 444 "$DIR"/*.crt

tar -c -f "$PWD/server-tls-$CA_ID.tar.gz" -vz -C "$BASEDIR" \
    tls-$CA_ID/srv.key tls-$CA_ID/srv.crt \
    tls-$CA_ID/ca.crt tls-$CA_ID/ta.key \
    tls-$CA_ID/dh$DH_BITS.pem server-$CA_ID.conf

tar -c -f "$PWD/client-tls-$CA_ID.tar.gz" -vz -C "$BASEDIR" \
    tls-$CA_ID/cli.key tls-$CA_ID/cli.crt \
    tls-$CA_ID/ca.crt tls-$CA_ID/ta.key \
    tls-$CA_ID/dh$DH_BITS.pem client-$CA_ID.conf

rm -rf "$BASEDIR"

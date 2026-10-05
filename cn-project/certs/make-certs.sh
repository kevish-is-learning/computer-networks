#!/bin/bash
# Run on Mac 2 (edge). Creates a root CA and a server certificate signed by it.
# rootCA.key and server.key must NEVER be shared or committed. Only rootCA.pem leaves Mac 2.
set -e
mkdir -p ~/cn-certs && cd ~/cn-certs
cp "$(dirname "$0")/ca.cnf" "$(dirname "$0")/leaf.cnf" .

# Homebrew OpenSSL 3 (macOS's own openssl is LibreSSL)
OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
$OPENSSL version

# Root CA
$OPENSSL req -x509 -new -nodes -newkey rsa:2048 \
  -keyout rootCA.key -out rootCA.pem -days 825 \
  -config ca.cnf -extensions v3_ca

# Server key + CSR, signed by the CA (SAN comes from leaf.cnf)
$OPENSSL req -new -nodes -newkey rsa:2048 \
  -keyout server.key -out server.csr -config leaf.cnf
$OPENSSL x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key \
  -CAcreateserial -out server.crt -days 397 -sha256 \
  -extfile leaf.cnf -extensions v3_leaf

# Verify
$OPENSSL verify -CAfile rootCA.pem server.crt
$OPENSSL x509 -in server.crt -noout -ext subjectAltName

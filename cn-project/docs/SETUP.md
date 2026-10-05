# Setup Guide (Phase 1)

Team name `solo`; IPs: Mac 1 = 10.7.7.5, Mac 2 = 10.7.21.121, Mac 3 = 10.7.26.163.
Copy commands from this file, not through chat apps (they alter quotes and backticks).

## All Macs
1. Join the same Wi-Fi. Turn off VPNs, iCloud Private Relay and any DNS filter/ad-blocker app.
2. Wi-Fi settings: Private Wi-Fi Address = Fixed.
3. Check tools and reachability:
```bash
which curl dig nslookup ping openssl
ipconfig getifaddr en0
ping -c 3 <other Mac IP>
ipconfig getoption en0 subnet_mask
route -n get default | grep gateway
ifconfig en0 | grep ether
```

## Mac 1: DNS server
```bash
brew install dnsmasq
dig @8.8.8.8 google.com +short                       # outside DNS reachable
cp $(brew --prefix)/etc/dnsmasq.conf $(brew --prefix)/etc/dnsmasq.conf.original
# copy dns/dnsmasq.conf to $(brew --prefix)/etc/dnsmasq.conf
$(brew --prefix)/sbin/dnsmasq --test --conf-file=$(brew --prefix)/etc/dnsmasq.conf   # syntax check OK
sudo brew services restart dnsmasq                   # restart so the new config is read
dig @127.0.0.1 app.solo.test +short                  # 10.7.21.121
caffeinate -dims                                     # keep awake, leave tab open
```

## Mac 2 and Mac 3: use the private DNS
```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.7.5
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
dig app.solo.test +short       # 10.7.21.121
dig google.com +short          # forwarding works
```
Undo: `sudo networksetup -setdnsservers Wi-Fi empty`.
If `dig` goes to an unexpected server, check `scutil --dns | head -20` for a supplemental resolver (a DNS filter or VPN app) and turn it off.

## Mac 3: backends
```bash
mkdir -p ~/cn-backend && cd ~/cn-backend
npm init -y && npm install express
# copy backend/server.js to ~/cn-backend/server.js
BACKEND=A PORT=3001 node server.js      # terminal tab 1
BACKEND=B PORT=3002 node server.js      # terminal tab 2
```
Allow incoming connections if macOS asks.

## Mac 2: nginx, certificates, HTTPS
```bash
brew install nginx openssl@3
bash certs/make-certs.sh                # creates ~/cn-certs/rootCA.pem, server.crt, server.key
mkdir -p /opt/homebrew/etc/nginx/certs
cp ~/cn-certs/server.crt /opt/homebrew/etc/nginx/certs/solo.crt
cp ~/cn-certs/server.key /opt/homebrew/etc/nginx/certs/solo.key
chmod 600 /opt/homebrew/etc/nginx/certs/solo.key
# copy nginx/solo.conf to /opt/homebrew/etc/nginx/servers/solo.conf
sudo nginx -t && sudo brew services restart nginx
curl -i --cacert ~/cn-certs/rootCA.pem https://app.solo.test/api/status
```
Never share `rootCA.key` or `server.key`. Only `rootCA.pem` is sent to the other Macs (AirDrop).

## Trust the CA on every Mac (Mac 1, Mac 2, Mac 3)
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain <path>/rootCA.pem
curl -i https://app.solo.test/api/status     # HTTP/2 200 with no -k
```

## Verify the whole chain
```bash
for i in 1 2 3 4; do curl -si https://app.solo.test/api/status | grep -i x-backend; done
```
`A B A B` means DNS, TCP, TLS, nginx and both backends are working.

# The Five Required Failure Demonstrations

All run from Mac 3 (a client) unless noted. Each was restored afterwards.

## 1. Wrong DNS server
```bash
sudo networksetup -setdnsservers Wi-Fi 8.8.8.8
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
dig app.solo.test
curl https://app.solo.test/api/status
ping -c 2 10.7.21.121
curl --resolve app.solo.test:443:10.7.21.121 https://app.solo.test/api/status
# restore
sudo networksetup -setdnsservers Wi-Fi 10.7.7.5
```
Observed: `status: NXDOMAIN` from `SERVER: 8.8.8.8#53`, authority section is the root zone; `curl: (6) Could not resolve host`; ping 2/2 replies; `--resolve` returned `200` with JSON (backend A).
**Proves:** DNS and IP connectivity are independent. `.test` does not exist in public DNS.

## 2. DNS record points to the wrong IP
On Mac 1 the `app` record was changed to Mac 3 (10.7.26.163), which runs no HTTPS service on 443, and dnsmasq restarted.
```
$ dig app.solo.test +short                 -> 10.7.26.163        (resolution succeeds, wrong IP)
$ curl -m 5 https://app.solo.test/api/status
curl: (7) Failed to connect to app.solo.test port 443 ... Couldn't connect to server
$ curl https://api.solo.test/api/status    -> 200 {"backend":"A",...}   (its record is still correct)
```
Restored by reversing the edit, restarting dnsmasq and flushing the client cache (`dig` returned 10.7.21.121).
**Proves:** DNS is a directory, not a connection. The failure appears later at TCP.

## 3. One backend stopped (Backend A)
```
$ for i in 1 2 3 4 5 6; do curl -si https://app.solo.test/api/status | grep -i x-backend; done
x-backend: B  (six times, no errors)
```
nginx error log on Mac 2:
```
2026/10/05 22:47:45 [error] ... connect() failed (61: Connection refused) while connecting to upstream,
client: 10.7.26.163, server: app.solo.test, request: "GET /api/status HTTP/2.0",
upstream: "http://10.7.26.163:3001/api/status"
```
After restarting A (and waiting out `fail_timeout`): `B B A B A B`, then alternating.
**Proves:** `max_fails` + `fail_timeout` mark a backend down; `proxy_next_upstream` retries on the other one. Cloud equivalent: load balancer health checks.

## 4. Both backends stopped
```
$ dig app.solo.test +short   -> 10.7.21.121
$ curl -vi https://app.solo.test/api/status | grep ...
SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
HTTP/2 502
server: nginx/1.31.6          (no x-backend header)
```
After restarting both: `A B A B`.
**Proves:** DNS, TCP and TLS work up to the edge; the failure is behind nginx. 502 = the edge is fine, its upstream is not.

## 5. Wrong destination port
```
$ nc -vz 10.7.21.121 443    -> Connection ... succeeded!
$ nc -vz 10.7.21.121 8443   -> nc: connectx ... failed: Connection refused
$ curl -m 5 https://app.solo.test:8443/api/status
curl: (7) Failed to connect to app.solo.test port 8443 ... Couldn't connect to server
$ ping -c 2 10.7.21.121     -> 2/2 replies, 0% loss
```
**Proves:** the IP picks the machine, the port picks the service. In Wireshark a refused port is a SYN answered by RST, with no SYN-ACK.

## Summary

| # | Demo | Failing layer | Signature |
|---|---|---|---|
| 1 | Wrong DNS server | DNS | NXDOMAIN, curl (6) |
| 2 | Wrong IP in record | TCP | resolves, then curl (7) |
| 3 | One backend down | none (service continues) | all B; log shows connection refused |
| 4 | Both backends down | Application | HTTP 502, no `x-backend` |
| 5 | Wrong port | TCP | connection refused on 8443 |

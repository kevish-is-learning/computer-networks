# Evidence Log (Phase 1)

Terminal output captured during the build. Screenshots and captures are listed at the end and live in `evidence/`.

## A. LAN setup

Ping results (3 packets each, 0% loss, `ttl=64` on all):

| From | To | Result |
|---|---|---|
| Mac 2 | Mac 1 (10.7.7.5) | 3/3, avg 33.4 ms |
| Mac 2 | Mac 3 (10.7.26.163) | 3/3, avg 21.2 ms |
| Mac 3 | Mac 1 | 3/3, avg 23.1 ms |
| Mac 3 | Mac 2 (10.7.21.121) | 3/3, avg 33.5 ms |
| Mac 1 | Mac 2 | 3/3, avg 184.9 ms |
| Mac 1 | Mac 3 | 3/3, avg 46.8 ms |

Network details (inventory table is in `ARCHITECTURE.md`): mask 255.255.224.0 (/19), gateway 10.7.0.1, interface en0 on all three.

## B. Private DNS

Mac 1, outside DNS reachable (forwarding):
```
$ dig @8.8.8.8 google.com +short
142.250.29.138 142.250.29.100 142.250.29.101 142.250.29.102 142.250.29.139 142.250.29.113
```
Mac 1, syntax check and local test:
```
dnsmasq: syntax check OK.
$ dig @127.0.0.1 app.solo.test +short
10.7.21.121
```
Mac 2 and Mac 3, direct to the DNS server:
```
$ dig @10.7.7.5 app.solo.test +short   -> 10.7.21.121
$ dig @10.7.7.5 api.solo.test +short   -> 10.7.21.121
```
Mac 2 and Mac 3 after `networksetup -setdnsservers Wi-Fi 10.7.7.5` (no `@`):
```
$ dig app.solo.test +short   -> 10.7.21.121
$ dig google.com +short      -> Google IPs (forwarding works)
```
Mac 3 initially returned nothing because a DNS filter tool added a supplemental resolver (`scutil --dns` showed `192.0.2.42` first, answering NXDOMAIN). After turning the tool off, `dig app.solo.test +short` returned `10.7.21.121`.

## C. Backends (from Mac 2 across the LAN)
```
$ curl -i http://10.7.26.163:3001/api/status
HTTP/1.1 200 OK
X-Backend: A
Cache-Control: no-store
{"backend":"A","status":"ok","time":"2026-10-05T16:24:49.361Z"}

$ curl -i http://10.7.26.163:3002/api/status
HTTP/1.1 200 OK
X-Backend: B
Cache-Control: no-store
{"backend":"B","status":"ok","time":"2026-10-05T16:24:52.916Z"}
```
Backend log on Mac 3 (the backend sees the edge's IP, not the client's):
```
Backend A listening on 0.0.0.0:3001
2026-10-05T16:24:49.352Z  from=10.7.21.121  GET /api/status
Backend B listening on 0.0.0.0:3002
2026-10-05T16:28:47.205Z  from=10.7.21.121  GET /api/status
```

## D. Load balancer
```
$ sudo nginx -t
nginx: the configuration file /opt/homebrew/etc/nginx/nginx.conf syntax is ok
nginx: configuration file /opt/homebrew/etc/nginx/nginx.conf test is successful

$ for i in 1 2 3 4; do curl -si http://app.solo.test/api/status | grep X-Backend; done
X-Backend: A
X-Backend: B
X-Backend: A
X-Backend: B
```
Same A/B/A/B result from Mac 3 (a second client).

## E. HTTPS / TLS

Certificate checks (Mac 2):
```
OpenSSL 3.6.5
server.crt: OK
X509v3 Subject Alternative Name:
    DNS:app.solo.test, DNS:api.solo.test
```
HTTPS with only our CA (no `-k`):
```
$ curl -i --cacert ~/cn-certs/rootCA.pem https://app.solo.test/api/status
HTTP/2 200
server: nginx/1.31.6
x-backend: A
```
After installing the CA in each Mac's System keychain, no flags needed (Mac 1, Mac 2, Mac 3):
```
$ curl -i https://app.solo.test/api/status      -> HTTP/2 200
$ for i in 1 2 3 4; do curl -si https://app.solo.test/api/status | grep -i x-backend; done
x-backend: A / B / A / B
```
HTTP redirect:
```
$ curl -i http://app.solo.test/api/status
HTTP/1.1 301 Moved Permanently
Location: https://app.solo.test/api/status
```
HTTP versions (ALPN negotiated in the TLS handshake):
```
$ curl -sI --http1.1 https://app.solo.test/api/status | head -1   -> HTTP/1.1 200 OK
$ curl -sI --http2   https://app.solo.test/api/status | head -1   -> HTTP/2 200
```
Certificate details from `curl -v`:
```
ALPN: curl offers h2,http/1.1
ALPN: server accepted h2
subject: CN=app.solo.test
issuer: CN=solo Local Root CA
SSL certificate verify ok.
```
Trust-store check:
```
$ security find-certificate -a -c "solo Local Root CA" /Library/Keychains/System.keychain | grep -E "labl|alis"
"alis"<blob>="solo Local Root CA"
"labl"<blob>="solo Local Root CA"
```

## F. HTTP caching
```
$ curl -I https://app.solo.test/api/cached
HTTP/2 200
cache-control: public, max-age=60
etag: W/"31-BhpixH3upRuqs+uGPrcnwzO1ql0"

$ curl -I -H "If-None-Match: $ETAG" https://app.solo.test/api/cached
HTTP/2 304
cache-control: public, max-age=60
etag: W/"31-BhpixH3upRuqs+uGPrcnwzO1ql0"
```
Six conditional requests returned `304` from both backends (`x-backend: B A B A B A`), because both produce the same body and so the same ETag.

| Case | What happens |
|---|---|
| Fresh hit | Within `max-age`, the client reuses its copy and sends nothing |
| Conditional request | After expiry the client sends `If-None-Match`; server replies 304, no body |
| Full request | No cached copy; server replies 200 with the whole body |

## G. Wireshark (captured on Mac 3, interface en0, filter `host 10.7.7.5 or host 10.7.21.121`)

Request used: `curl -v --tls-max 1.2 https://app.solo.test/api/status` (TLS 1.2 so the Certificate message is visible).

| Layer | Packet | Observed |
|---|---|---|
| DNS query | 33 | 10.7.26.163:49943 -> 10.7.7.5:53, UDP, A app.solo.test |
| DNS response | 36 | 10.7.7.5:53 -> client:49943, No error, 1 answer 10.7.21.121 |
| TCP SYN | 37 | 10.7.26.163:60675 -> 10.7.21.121:443, Seq 0, Win 65535, MSS 1460, SACK permitted |
| TLS Client Hello | stream 0 | TLS 1.2, 46 cipher suites, SNI `app.solo.test`, ALPN `h2`, `http/1.1` |
| TLS Certificate | stream 0 | issuer `solo Local Root CA`, sha256WithRSAEncryption, followed by Server Key Exchange |
| Application Data | 48 | 10.7.21.121:443 -> :60675, Content Type 23, encrypted, Seq 1349, Ack 316 |

`curl -v` handshake: Client hello, Server hello, Certificate, Server key exchange, Server finished, Client key exchange, Change cipher spec, Finished (both ways); `TLSv1.2 / ECDHE-RSA-CHACHA20-POLY1305`, `HTTP/2 200`, `x-backend: A`.

Ports: DNS 49943 (ephemeral) to 53 (UDP); HTTPS 60675 (ephemeral) to 443 (TCP).

## H. Failure demonstrations
See `FAILURE-DEMOS.md`.

## Files in `evidence/`

Full per-file index with descriptions: `../evidence/README.md`.

| File | Content |
|---|---|
| `captures/cn-phase1.pcapng`, `captures/cn-phase1-app-flow.pcapng` | Full capture and clean single flow |
| `curl-verbose.txt` | `curl -v --tls-max 1.2` output (Mac 3) |
| `dns-setting-mac3.png` | Wi-Fi DNS = 10.7.7.5 |
| `browser-https-status.png`, `browser-certificate.png`, `keychain-solo-ca.png` | HTTPS in the browser, certificate chain, CA trusted in Keychain |
| `wireshark-dns-list/query/response.png`, `wireshark-syn.png`, `wireshark-client-hello.png`, `wireshark-certificate.png`, `wireshark-encrypted-data.png` | Packet screenshots for Task G |

## I. Final verification outputs (submission day, 5 Oct 2026)

**dig from a client (Mac 2), private DNS:**
```
$ dig app.solo.test
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 43646
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; ANSWER SECTION:
app.solo.test.		60	IN	A	10.7.21.121
;; Query time: 12 msec
;; SERVER: 10.7.7.5#53(10.7.7.5)
```

**dig to public DNS (name is private):**
```
$ dig @8.8.8.8 app.solo.test
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 4839
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; AUTHORITY SECTION:
.			86332	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2026100500 1800 900 604800 86400
;; SERVER: 8.8.8.8#53(8.8.8.8)
```

**HTTPS without -k (Mac 3):** `curl -v https://app.solo.test` -> `SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256`, `subject: CN=app.solo.test`, `subjectAltName ... matched`, `issuer: CN=solo Local Root CA`, `SSL certificate verify ok`, `HTTP/2 200`, `x-backend: A`.

**Load balancing, six consecutive requests (Mac 3):**
```
x-backend: A   x-backend: B   x-backend: A   x-backend: B   x-backend: A   x-backend: B
```

**Caching headers:**
```
$ curl -sI https://app.solo.test/api/cached
HTTP/2 200
date: Mon, 05 Oct 2026 17:59:48 GMT
x-backend: B
cache-control: public, max-age=60
etag: W/"31-BhpixH3upRuqs+uGPrcnwzO1ql0"
```

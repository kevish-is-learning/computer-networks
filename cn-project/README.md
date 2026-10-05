# CN Project: Private Network Service Platform (Phase 1)

A client types `https://app.solo.test`. The name is resolved by **our own DNS server**, the request goes over **HTTPS to an nginx edge**, and nginx **load-balances** it across **two backends**. Every step is proven with `dig`, `curl` and Wireshark.

```
Client (Mac 2 or Mac 3)
  |-- 1. DNS query  UDP :53 ---------> Mac 1  dnsmasq             (Private DNS)
  |      answer: app.solo.test = Mac 2's IP
  '-- 2. HTTPS      TCP :443 ---------> Mac 2  nginx               (Edge: TLS + load balancer)
                                          |-- plain HTTP :3001 --> Mac 3  Node/Express  (Backend A)
                                          '-- plain HTTP :3002 --> Mac 3  Node/Express  (Backend B)
```

| Machine | Role | Runs | IP |
|---|---|---|---|
| Mac 1 | Private DNS + test client | dnsmasq (port 53) | 10.7.7.5 |
| Mac 2 | Edge: reverse proxy, TLS, load balancer | nginx (80, 443) | 10.7.21.121 |
| Mac 3 | Backend A (3001) + Backend B (3002) + Wireshark capture client | 2 Node/Express processes | 10.7.26.163 |

Team domain: `solo.test` (reserved `.test` namespace; `.local` is avoided because it conflicts with mDNS). Names: `app.solo.test`, `api.solo.test`.

Team of three, so the Backend B and capture-client roles are combined onto Mac 3 (allowed for teams of 2 to 3).

## Repository layout

```
cn-project/
|-- README.md
|-- .gitignore
|-- backend/        server.js, package.json
|-- dns/            dnsmasq.conf
|-- nginx/          solo.conf
|-- certs/          ca.cnf, leaf.cnf, make-certs.sh   (keys are git-ignored)
|-- docs/
|   |-- topology.png/.svg  annotated topology diagram
|   |-- ARCHITECTURE.md   topology, IP/service table, request flow, OSI mapping, cloud equivalents
|   |-- SETUP.md          per-machine setup and launch instructions
|   |-- RUNBOOK.md        session start, IP-change fixes, layer-by-layer diagnosis
|   |-- EVIDENCE.md       every task mapped to its terminal output
|   |-- FAILURE-DEMOS.md  the five required failure demonstrations
|   '-- VIVA.md           short answers for the viva
'-- evidence/       11 screenshots, curl-verbose.txt, 2 .pcapng captures (index in evidence/README.md)
```

## Endpoints (each backend)

| Endpoint | Response | Cache |
|---|---|---|
| `GET /` | JSON confirming the service runs | none |
| `GET /api/status` | `{"backend":"A","status":"ok","time":...}` and header `X-Backend: A` | `no-store` |
| `GET /api/cached` | identical body on A and B | `public, max-age=60` + ETag |

## Phase 1 status

| Task | Description | Status |
|---|---|---|
| A | LAN, IP inventory, ping | Done |
| B | Private DNS, two clients | Done |
| C | Two backends | Done |
| D | nginx round-robin load balancer | Done |
| E | HTTPS with own CA, no `-k` | Done |
| F | HTTP caching, 304 | Done |
| G | Wireshark: DNS, TCP, TLS | Done |
| - | Five failure demonstrations | Done |

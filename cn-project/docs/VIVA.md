# Viva Notes

Every member must be able to explain every part, not only the part they configured.

- **DNS vs connection:** DNS only finds the IP (UDP 53). The TCP/TLS connection is a separate, later step. Failure demos 1 and 2 prove it.
- **Why `.test`:** reserved for private use; public DNS answers NXDOMAIN from the root zone. `.local` belongs to mDNS.
- **TTL 64:** macOS starts at 64 and each router hop subtracts 1. Replies still at 64 mean no router in between: same LAN segment. Frames are addressed to the target Mac's own MAC, not the gateway's.
- **Subnet:** 255.255.224.0 is /19, covering 10.7.0.0 to 10.7.31.255.
- **TLS termination:** TLS ends at nginx; nginx to backend is plain HTTP. The backend logs the edge's IP; the real client is in `X-Forwarded-For`.
- **Why the client never knows backend IPs:** it only knows the name; DNS points at the edge; the edge chooses the backend.
- **TLS 1.2 handshake:** Client Hello (SNI, ALPN) -> Server Hello -> Certificate -> Server Key Exchange -> Server Hello Done -> Client Key Exchange -> Change Cipher Spec -> Finished (both directions). After that, Application Data is encrypted.
- **TLS 1.3 vs 1.2:** in 1.3 the Certificate is encrypted, so the capture used `--tls-max 1.2`.
- **Why our CA works:** it is marked `CA:TRUE` with Key Cert Sign, and every client keychain trusts it, so any certificate it signs with a matching SAN validates. Browsers ignore the Common Name; the SAN is what counts.
- **ALPN:** HTTP/1.1 vs HTTP/2 is negotiated inside the TLS handshake (client offers h2, http/1.1; server picked h2). HTTP/3 (QUIC over UDP 443) is explanation-only.
- **Load balancing:** round-robin by default; `max_fails` + `fail_timeout` mark a backend down; `proxy_next_upstream` retries on the other. Cloud equivalent: ALB health checks.
- **Caching:** identical body on A and B gives an identical ETag, so 304 works whichever backend answers. Fresh hit (no request) vs conditional request (304, no body) vs full request (200 with body). `/api/status` is `no-store` because its body (backend name, time) differs.
- **Ports:** client uses a random ephemeral port (49943 for DNS, 60675 for HTTPS in our capture); servers use well-known ports (53, 443) or fixed ones (3001, 3002). A socket is IP + port at each end.
- **TCP reliability:** sequence/acknowledgement numbers (SYN had Seq 0; the server's data packet showed Seq 1349, Ack 316), SACK and retransmission; `Win=` is flow control (65535 in the SYN).
- **502 Bad Gateway:** the edge works but its upstream does not.
- **Error codes:** curl (6) = DNS, curl (7) = TCP, `SSL certificate problem` = TLS, 502 = application.
- **Single points of failure:** Mac 1 (DNS) and Mac 2 (edge). Phase 2 adds a backup resolver and a standby edge with a DNS cutover.
- **Team of three:** Backend A, Backend B and the capture client share Mac 3; they differ only by port.

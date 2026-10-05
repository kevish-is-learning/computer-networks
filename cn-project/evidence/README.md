# Evidence index

Every item below is in this folder. Terminal outputs for each task are in `../docs/EVIDENCE.md` and `../docs/FAILURE-DEMOS.md`.

| File | Task | What it shows |
|---|---|---|
| `captures/cn-phase1.pcapng` | G | Full Wireshark capture taken on Mac 3 (interface en0, filter `host 10.7.7.5 or host 10.7.21.121`) |
| `captures/cn-phase1-app-flow.pcapng` | G | Clean flow only: DNS query/response + TCP/TLS stream on port 60675 |
| `curl-verbose.txt` | G | `curl -v --tls-max 1.2` from Mac 3: full TLS 1.2 handshake, `SSL certificate verify ok`, `HTTP/2 200`, `x-backend: A` |
| `dns-setting-mac3.png` | B | Mac 3 System Settings > Wi-Fi > Details > DNS = `10.7.7.5` (account name masked) |
| `browser-https-status.png` | D/E | `https://app.solo.test/api/status` loaded in Chrome, response from Backend B |
| `browser-certificate.png` | E | Certificate viewer: issued to `app.solo.test` by `solo Local Root CA`, valid 5 Oct 2026 to 6 Nov 2027 |
| `keychain-solo-ca.png` | E | Keychain Access: `solo Local Root CA`, "marked as trusted for all users", Always Trust, Key Cert Sign |
| `wireshark-dns-list.png` | G | Packet list filtered by `dns`; all queries go to 10.7.7.5 |
| `wireshark-dns-query.png` | G | Frame 33: 10.7.26.163:49943 -> 10.7.7.5:53, UDP, A `app.solo.test` |
| `wireshark-dns-response.png` | G | Frame 36: 10.7.7.5:53 -> :49943, No error, 1 answer, `app.solo.test A 10.7.21.121`, 83 ms |
| `wireshark-syn.png` | G | Frame 37: 10.7.26.163:60675 -> 10.7.21.121:443, SYN, Seq 0, MSS 1460, SACK permitted |
| `wireshark-client-hello.png` | G | TLS 1.2 Client Hello: SNI `app.solo.test`, ALPN `h2`, `http/1.1` |
| `wireshark-certificate.png` | G | Server Certificate message, issuer `solo Local Root CA`, sha256WithRSAEncryption |
| `wireshark-encrypted-data.png` | G | Frame 48: TLS Application Data (type 23), payload encrypted |

Mac 2's DNS setting is proven by the terminal output in `../docs/EVIDENCE.md` section B (plain `dig app.solo.test +short` from Mac 2 returns 10.7.21.121 after `networksetup -setdnsservers Wi-Fi 10.7.7.5`).

`rootCA.key` and `server.key` are never stored here or in the repository.

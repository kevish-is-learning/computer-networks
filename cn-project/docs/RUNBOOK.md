# Runbook

## Start of every session
1. On all Macs: `ipconfig getifaddr en0`. The college DHCP may hand out new IPs.
2. If an IP changed:

| Changed | Fix |
|---|---|
| Mac 2 (edge) | Mac 1: update both `host-record` lines, `sudo brew services restart dnsmasq`; clients flush DNS cache |
| Mac 3 (backends) | Mac 2: update the `upstream` block, `sudo nginx -t && sudo brew services restart nginx` |
| Mac 1 (DNS) | Each client: `sudo networksetup -setdnsservers Wi-Fi <new IP>` |

3. Restart what does not survive sleep: both `node server.js` backends (Mac 3) and `caffeinate -dims` (Mac 1 and Mac 2). dnsmasq, nginx, client DNS settings, the trusted CA and configs survive.
4. One test checks everything: `for i in 1 2 3 4; do curl -si https://app.solo.test/api/status | grep -i x-backend; done` shows A B A B.

## Layer-by-layer diagnosis (bottom-up)

| # | Check | Command | If it fails |
|---|---|---|---|
| 1 | Name resolution | `dig app.solo.test +short` | Mac 1 asleep? dnsmasq running? client resolver set? hidden DNS filter? |
| 2 | IP reachability | `ping -c 2 10.7.21.121` | Same Wi-Fi? IP changed? |
| 3 | TCP port | `nc -vz 10.7.21.121 443` | nginx stopped or wrong port |
| 4 | TLS | `curl -v https://app.solo.test` | CA trust, SAN, expired certificate |
| 5 | Application | look for `502` | backends stopped or wrong upstream IP |

curl codes: `(6) Could not resolve host` = DNS, `(7) Failed to connect` = TCP, `SSL certificate problem` = TLS, `502` = backend.
`curl -s` hides errors; rerun without `-s` when something prints nothing.

## Known issues we hit

| Symptom | Cause | Fix |
|---|---|---|
| `dig @127.0.0.1` empty after config written | dnsmasq was already running with the old config | `sudo brew services restart dnsmasq` |
| Plain `dig` empty on one client, `dig @10.7.7.5` works | A supplemental resolver (192.0.2.42) from a DNS tool intercepted `.test` | Turn off the tool; verify with `scutil --dns` |
| `curl: (6)` on the DNS Mac itself | Its own resolver was never set to 10.7.7.5 | `sudo networksetup -setdnsservers Wi-Fi 10.7.7.5` |
| `SSL certificate problem` on the edge Mac | CA not in its System keychain | `sudo security add-trusted-cert ...` |
| Old config from an earlier attempt in nginx `servers/` | Left over `team1.conf` | Move it out and reload |
| Certificate packet unreadable in Wireshark | TLS 1.3 encrypts it | Capture with `curl --tls-max 1.2` |

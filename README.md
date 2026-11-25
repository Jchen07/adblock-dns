# adblock-dns

Self-hosted DNS ad blocker using [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) in Docker, so Chrome on iPhone (which has no extensions) loads fewer web ads.

Current state: **local test** on a Mac, home Wi-Fi only.

```
iPhone -> AdGuard Home (blocks ad domains) -> Quad9 over HTTPS -> internet
```

## What it does and does not do
| Blocks | Does not block |
|---|---|
| Banners from ad networks, trackers, many redirect domains | YouTube and in-feed ads (same domain as the content) |
| Known malware/phishing domains (via Quad9) | Empty ad slots (DNS cannot edit pages) |

It does not make you anonymous: the upstream DNS sees your non-blocked queries, and your ISP still sees where you connect.

## Requirements
- Mac with Docker Desktop (tested setup: macOS). Other OSes need different commands to find the IP.
- iPhone on the same Wi-Fi.

## 1. Run
```sh
cp .env.example .env     # set LAN_IP to the output of: ipconfig getifaddr en0
docker compose up -d
```
Ports: DNS (53) listens only on `LAN_IP`; the admin panel (3000) only on `127.0.0.1`.

## 2. Setup wizard: http://127.0.0.1:3000
1. Admin web interface: all interfaces, port **3000**. The default is 80, which is not published, so the panel would be unreachable.
2. DNS server: all interfaces, port **53**.
3. Create a user and a strong password. Keep them in a password manager, never in this repo.
4. The "configure your devices" page is informational: click Next.

The addresses with `172.x` shown by the wizard are internal container IPs.

## 3. Settings in the panel
| Where | Setting |
|---|---|
| Settings > DNS settings > Upstream DNS | `https://dns.quad9.net/dns-query` (replace the default; `dns10` does not block malware). Test, then Apply |
| Settings > General > Query log rotation | 24 hours |
| Settings > General | "Browsing security" and "Parental control" off |
| Filters > DNS blocklists | Keep **AdGuard DNS filter**; Add blocklist > Choose from the list > **HaGeZi's Pro Blocklist** |
| Filters > Custom filtering rules | Optional, one per line: `\|\|example-ad-domain.com^` |

If the list is not in the picker, add it by URL: `https://adguardteam.github.io/HostlistsRegistry/assets/filter_48.txt`.

## 4. Check from the Mac
```sh
dig @<LAN_IP> example.com +short       # real IP
dig @<LAN_IP> doubleclick.net +short   # 0.0.0.0 = blocked
```

## 5. iPhone
1. Settings > Wi-Fi > (i) on the home network > Configure DNS > **Manual**.
2. Remove **all** existing servers, add `<LAN_IP>`, Save.
3. On that network turn off "Limit IP Address Tracking" and iCloud Private Relay, and any VPN.
4. In Chrome: Settings > Content settings > Block pop-ups.
5. Toggle airplane mode to flush the DNS cache.

**Revert:** Configure DNS > Automatic.

## Keep the Mac's IP stable (optional)
- macOS: Wi-Fi > Details > Private Wi-Fi address > **Fixed**.
- Router: add a DHCP reservation for the Mac.

If the IP changes: update `.env`, run `docker compose up -d`, and update the iPhone.

## Troubleshooting
| Symptom | Fix |
|---|---|
| iPhone has no internet at home | Mac asleep, Docker stopped or IP changed. Set DNS to Automatic to recover |
| A site or app breaks | Query log > find the blocked domain > Unblock, or disable HaGeZi |
| Ads or redirects still appear | Check the query log for the new domain and add a custom rule. Ad networks rotate domains |

## Operations
```sh
docker compose logs -f
docker compose down      # set the iPhone DNS back to Automatic first
```
Update: change the image tag in `docker-compose.yml`, then `docker compose pull && docker compose up -d`. Check AdGuard Home's security advisories.

## Security
- Never expose port 53 or the panel to the internet: open resolvers get abused.
- `data/` holds the password hash and your browsing history. `data/`, `.env` and `local-notes.md` are git-ignored.

## Roadmap
1. Local test (current)
2. Measure for a few days
3. VPS with encrypted DNS and an iPhone profile
4. Hardening: access limits, Unbound, updates, alerts

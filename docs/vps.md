# Run it on a paid server (VPS)

So it works anywhere and no computer at home needs to stay on.

> Status: written plan, **not tested yet**.

```
iPhone --HTTPS--> Caddy (only /dns-query/<secret>) --> AdGuard Home --> Quad9
You    --SSH tunnel--> admin panel
```

## First, the basics
**What is a VPS?** A computer rented in a data center, always on, with its own public IP. You control it from the terminal (SSH). It replaces the computer at home running Docker.

**Do I need a domain?** You need a name pointing to the server so it can get an HTTPS certificate. It doesn't have to be paid.

| Name | Works here? | Why |
|---|---|---|
| `*.pages.dev`, `*.workers.dev` | No | Only for sites and functions hosted on Cloudflare |
| `user.github.io` | No | Only for GitHub Pages |
| `*.cloudfront.net`, `*.amazonaws.com` | No | Assigned by Amazon to its services, not suitable for your own certificate |
| DuckDNS (`name.duckdns.org`) | Yes | Free subdomain pointing to any IP |
| deSEC (`name.dedyn.io`) | Yes | Free, run by a non-profit |
| Your own domain | Yes | Paid, around 10 EUR/year |

**Is DuckDNS safe?** Reasonable for a personal test. It only turns your name into your server's IP; your DNS queries go encrypted straight to your server. Risks:
- Outages (donation-funded, no service guarantee): the iPhone can't find your server.
- A stolen token or account could point your name elsewhere and capture your queries. Keep the token secret and turn on 2FA on the account you log in with.
- Some filters block DuckDNS because subdomains have been abused for phishing.

For daily use, your own domain is the better choice.

**Free servers?** Conditions change, check them first:

| Provider | Catch |
|---|---|
| Oracle Cloud Always Free | Asks for a card, capacity not always available, idle machines may be reclaimed |
| Google Cloud e2-micro | Free only in US regions (more latency from Europe) |
| AWS | Free for limited time or credit on new accounts |

## What you need
| Item | Approx. cost (check current prices) |
|---|---|
| Small VPS, Ubuntu LTS, 1 GB RAM, near you | 4-6 EUR/month |
| Domain or subdomain (a free dynamic DNS name also works) | 0-12 EUR/year |
| SSH key on your computer | free |

## 1. Create the server
1. Create the VPS with your **SSH key** (no password login).
2. In the provider's firewall allow only TCP **22, 80, 443**. Never open 53 or 3000. Use the provider firewall: Docker can bypass `ufw`.
3. Add a DNS `A` record: `dns.yourdomain.com` -> server IP.

## 2. Prepare it
```sh
ssh root@SERVER_IP
apt update && apt upgrade -y
apt install -y unattended-upgrades
curl -fsSL https://get.docker.com -o get-docker.sh   # read it, then:
sh get-docker.sh
```
Disable SSH password login (`PasswordAuthentication no`) and restart SSH.

## 3. Files on the server (in `/opt/adblock`)
`docker-compose.yml`
```yaml
services:
  adguardhome:
    image: adguard/adguardhome:v1.0.0   # use the latest release
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000/tcp"       # panel: SSH tunnel only
    volumes:
      - ./data/work:/opt/adguardhome/work
      - ./data/conf:/opt/adguardhome/conf
    networks: [web]
  caddy:
    image: caddy:2
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    environment:
      DOMAIN: ${DOMAIN}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data/caddy:/data
    networks: [web]
networks:
  web:
    ipam:
      config:
        - subnet: 172.30.0.0/24
```
`.env`
```
DOMAIN=dns.yourdomain.com
```
`Caddyfile` (gets the HTTPS certificate by itself; everything except DNS returns 404)
```
{$DOMAIN} {
    handle /dns-query/* {
        reverse_proxy adguardhome:3000
    }
    handle {
        respond 404
    }
}
```

## 4. Start and set up
```sh
cd /opt/adblock && docker compose up -d
```
On your computer open a tunnel and keep it open:
```sh
ssh -L 3000:127.0.0.1:3000 root@SERVER_IP
```
Open http://127.0.0.1:3000 (stop the local copy first, it uses the same port) and repeat the setup from the [README](../README.md): web port **3000**, new strong password, Quad9, 24 h logs, HaGeZi Pro.

## 5. Allow only your devices
1. Create a long random ID per device, for example with `openssl rand -hex 12`. Treat it like a password.
2. Panel > Settings > DNS settings > Access settings > **Allowed clients**: one ID per line.

## 6. Let Caddy talk to AdGuard
```sh
cd /opt/adblock && docker compose stop adguardhome
nano data/conf/AdGuardHome.yaml
```
Change:
```yaml
http:
  doh:
    insecure_enabled: true      # safe here: only Caddy reaches it, inside Docker
dns:
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
    - 172.30.0.0/24
```
```sh
docker compose start adguardhome
```

## 7. Check
```sh
Q='dns=q80BAAABAAAAAAAAA3d3dwdleGFtcGxlA2NvbQAAAQAB'
curl -s -o /dev/null -w '%{http_code}\n' "https://dns.yourdomain.com/dns-query/YOUR_ID?$Q"   # 200
curl -s -o /dev/null -w '%{http_code}\n' "https://dns.yourdomain.com/"                       # 404
```
Repeat the first command with a made-up ID: it must **not** resolve (check the query log).

## 8. iPhone profile
> Android: its **Private DNS** setting uses DNS-over-TLS (port 853), which this setup doesn't offer yet. Not covered here.

1. With the tunnel open and logged in, download:
   `http://127.0.0.1:3000/apple/doh.mobileconfig?host=dns.yourdomain.com&client_id=YOUR_ID`
2. AirDrop the file to the iPhone. It contains your secret ID: don't share or commit it.
3. Settings > General > VPN & Device Management > install the profile, then select it under **DNS**.
4. Set the Wi-Fi DNS back to **Automatic**.

Undo: select Automatic under DNS, or delete the profile.

## Maintenance
- Update: change the image tag, `docker compose pull && docker compose up -d`.
- Back up `data/conf`.
- Add an uptime check: if the server is down, the iPhone can't resolve names until you switch the profile off.
- The VPS provider can technically see your traffic; you are trusting it.
- Later: Unbound as your own resolver, alerts.

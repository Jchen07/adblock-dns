# adblock-dns

**Browse on your iPhone without being buried in ads.**

Chrome on iPhone doesn't allow ad-blocking extensions. This project blocks ads one step earlier, using your own computer.

## Why use it
- **Fewer ads and pop-ups** on websites
- **Fewer redirects** to shops and apps you never asked for
- **Works in Chrome and many apps**, nothing to install on the iPhone
- **Less tracking** and protection against known dangerous sites
- **Free**, and you control it

> It won't remove everything: YouTube and social media ads still show, and some empty spaces may remain. For now it only works at home.

## Where it works
| Where | Blocks ads? |
|---|---|
| Chrome, Safari, Firefox, Edge | Yes |
| Browsers with their own VPN or DNS turned on | No, they skip the filter |
| Games using ad networks | Often (banners and videos between matches) |
| In-game store offers | No, they come from the game itself |
| YouTube, Instagram, TikTok | Generally no |

**Gamers:** "watch an ad for a reward" may stop working, so you would not get the reward. Switch DNS to **Automatic** for a moment, or unblock the address in **Query log**.

## How it works
Your computer checks every address your iPhone asks for. If it belongs to an ad network, it gets blocked. It uses [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome).

## Setup
You need a Mac with Docker Desktop and an iPhone on the same Wi-Fi.

### 1. Start it
Find your Mac's IP:
```sh
ipconfig getifaddr en0
```
Then create the settings file, write that IP in `.env`, and start:
```sh
cp .env.example .env
docker compose up -d
```

### 2. First setup
Open http://127.0.0.1:3000 on the Mac:
- Change the web interface port from 80 to **3000**
- Keep the DNS port at **53**
- Create a user and a strong password
- On the "configure your devices" page, just click Next

### 3. Recommended settings
- **Settings > DNS settings:** replace the upstream server with `https://dns.quad9.net/dns-query`
- **Settings > General:** keep query logs for **24 hours**
- **Filters > DNS blocklists:** Add blocklist > Choose from the list > **HaGeZi's Pro Blocklist**

### 4. Connect the iPhone
1. **Settings > Wi-Fi**, tap **(i)** next to your network
2. **Configure DNS > Manual**
3. Delete all servers, add your Mac's IP, **Save**
4. Turn off "Limit IP Address Tracking", iCloud Private Relay and any VPN
5. Turn airplane mode on and off

Done. Open your usual websites.

## Problems?
| Problem | Solution |
|---|---|
| iPhone has no internet | Check the Mac is awake and Docker is running. To undo: **Configure DNS > Automatic** |
| Mac's IP changed | Update `.env`, run `docker compose up -d`, update the iPhone |
| A website stopped working | In the panel, open **Query log** and unblock the address |
| Some ads still appear | In the panel, find the address in **Query log** and block it |

To stop it, set the iPhone back to **Automatic**, then run `docker compose down`.

## Stay safe
- Never open this to the internet; it is meant for your home network only.
- Never share the `data/` folder: it contains your browsing history.
- Keep AdGuard Home updated.
